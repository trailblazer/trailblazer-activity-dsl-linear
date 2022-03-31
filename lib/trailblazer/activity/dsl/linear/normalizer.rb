module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizers are linear activities that process and normalize the options from a DSL call. They're
        # usually invoked from {Strategy#task_for}, which is called from {Path#step}, {Railway#pass}, etc.
        module Normalizer
          module_function

          # Wrap {task} with {Trailblazer::Option} and execute it with kw args in {#call}.
          # Note that this instance always return {Right}.
          class Task < TaskBuilder::Task
            def call(wrap_ctx, flow_options={})
              result = call_option(@task, [wrap_ctx, flow_options]) # DISCUSS: this mutates {ctx}.

              return wrap_ctx, flow_options
            end
          end

          def Task(user_proc)
            Normalizer::Task.new(Trailblazer::Option(user_proc), user_proc)
          end

          #   activity_normalizer.([{options:, user_options:, normalizer_options: }])
          def activity_normalizer(pipeline)
            pipeline = TaskWrap::Pipeline.prepend(
              pipeline,
              nil, # this means, put it to the beginning.
              {
              "activity.normalize_step_interface"       => Normalizer.Task(method(:normalize_step_interface)),      # first
              "activity.normalize_for_macro"            => Normalizer.Task(method(:merge_user_options)),
              "activity.normalize_normalizer_options"   => Normalizer.Task(method(:merge_normalizer_options)),
              "activity.normalize_non_symbol_options"   => Normalizer.Task(method(:normalize_non_symbol_options)),
              "activity.normalize_context"              => method(:normalize_context),
              "activity.normalize_id"                   => Normalizer.Task(method(:normalize_id)),
              "activity.normalize_override"             => Normalizer.Task(method(:normalize_override)),
              "activity.wrap_task_with_step_interface"  => Normalizer.Task(method(:wrap_task_with_step_interface)), # last
              "activity.inherit_option"                 => Normalizer.Task(method(:inherit_option)),
              },
            )

            pipeline = TaskWrap::Pipeline.prepend(
              pipeline,
              "path.wirings",
              {
              "activity.path_macro.forward_block"       => Normalizer.Task(method(:forward_block_for_path_branch)),     # forward the "global" block
              "activity.path_macro.path_to_track"       => Normalizer.Task(method(:convert_path_to_track)),     # forward the "global" block
              "activity.normalize_outputs_from_dsl"     => Normalizer.Task(method(:normalize_outputs_from_dsl)),     # Output(Signal, :semantic) => Id()
              "activity.normalize_connections_from_dsl" => Normalizer.Task(method(:normalize_connections_from_dsl)),
              "activity.input_output_extensions"        => Normalizer.Task(method(:input_output_extensions)),
              "activity.input_output_dsl"               => Normalizer.Task(method(:input_output_dsl)),
              },
            )

            pipeline = TaskWrap::Pipeline.append(
              pipeline,
              nil,
              ["activity.cleanup_options", method(:cleanup_options)]
            )

            pipeline
          end

          # Specific to the "step DSL": if the first argument is a callable, wrap it in a {step_interface_builder}
          # since its interface expects the step interface, but the circuit will call it with circuit interface.
          def normalize_step_interface(ctx, options:, **)
            options = case options
                      when Hash
                        # Circuit Interface
                        task  = options.fetch(:task)
                        id    = options[:id]

                        if task.is_a?(Symbol)
                          # step task: :find, id: :load
                          { **options, id: (id || task), task: Trailblazer::Option(task) }
                        else
                          # step task: Callable, ... (Subprocess, Proc, macros etc)
                          options # NOOP
                        end
                      else
                        # Step Interface
                        # step :find, ...
                        # step Callable, ... (Method, Proc etc)
                        { task: options, wrap_task: true }
                      end

            ctx[:options] = options
          end

          def wrap_task_with_step_interface(ctx, wrap_task: false, step_interface_builder:, task:, **)
            return unless wrap_task

            ctx[:task] = step_interface_builder.(task)
          end

          def normalize_id(ctx, id: false, task:, **)
            ctx[:id] = id || task
          end

          # {:override} really only makes sense for {step Macro(), {override: true}} where the {user_options}
          # dictate the overriding.
          def normalize_override(ctx, id:, override: false, **)
            return unless override
            ctx[:replace] = (id || raise)
          end

          # make ctx[:options] the actual ctx
          def merge_user_options(ctx, options:, **)
            # {options} are either a <#task> or {} from macro
            ctx[:options] = options.merge(ctx[:user_options]) # Note that the user options are merged over the macro options.
          end

          # {:normalizer_options} such as {:track_name} get overridden by user/macro.
          def merge_normalizer_options(ctx, normalizer_options:, options:, **)
            ctx[:options] = normalizer_options.merge(options)
          end

          def normalize_context(ctx, flow_options)
            ctx = ctx[:options]

            return ctx, flow_options
          end

          # Compile the actual {Seq::Row}'s {wiring}.
          # This combines {:connections} and {:outputs}
          def compile_wirings(ctx, connections:, outputs:, id:, **)
            ctx[:wirings] =
              connections.collect do |semantic, (search_strategy_builder, *search_args)|
                output = outputs[semantic] || raise("No `#{semantic}` output found for #{id.inspect} and outputs #{outputs.inspect}")

                search_strategy_builder.( # return proc to be called when compiling Seq, e.g. {ById(output, :id)}
                  output,
                  *search_args
                )
              end
          end

          # Move DSL user options such as {Output(:success) => Track(:found)} to
          # a new key {options[:non_symbol_options]}.
          # This allows using {options} as a {**ctx}-able hash in Ruby 2.6 and 3.0.
          def normalize_non_symbol_options(ctx, options:, **)
            symbol_options     = options.find_all { |k, v| k.is_a?(Symbol) }.to_h
            non_symbol_options = options.slice(*(options.keys - symbol_options.keys))
            # raise unless (symbol_options.size+non_symbol_options.size) == options.size

            ctx[:options] = symbol_options.merge(non_symbol_options: non_symbol_options)
          end

          # Forward the block to the DSL's {PathBranch} instance.
          #   step ..., Output(:semantic) => Path() do .. end
          #
          # Replace a block-expecting {PathBranch} instance with another one that's holding
          # the global {:block} from {#step}.
          def forward_block_for_path_branch(ctx, non_symbol_options:, block: false, **)
            return unless block

            output, path_branch =
              non_symbol_options.find { |output, cfg| cfg.kind_of?(Linear::Helper::PathBranch) }

            path_branch_with_block = Linear::Helper::PathBranch.new(path_branch.options.merge(block: block)) # DISCUSS: lots of internal knowledge here.

            ctx[:non_symbol_options] = non_symbol_options.merge(output => path_branch_with_block)
          end

          # Convert all occurrences of Path() to a corresponding {Track}.
          # The {Track} instance contains all additional {adds} steps.
          def convert_path_to_track(ctx, non_symbol_options:, block: false, **)
            new_tracks = non_symbol_options.
              find_all { |output, cfg| cfg.kind_of?(Linear::Helper::PathBranch) }.
              collect {  |output, cfg| [output, Linear::Helper::Path.convert_path_to_track(block: ctx[:block], **cfg.options)]  }.
              to_h

            ctx[:non_symbol_options] = non_symbol_options.merge(new_tracks)
          end

          # Process {Output(:semantic) => target} and make them {:connections}.
          def normalize_connections_from_dsl(ctx, connections:, adds:, non_symbol_options:, **)
            # Find all {Output() => Track()/Id()/End()}
            output_configs = non_symbol_options.find_all{ |k,v| k.kind_of?(Activity::DSL::Linear::OutputSemantic) }
            return unless output_configs.any?

            output_configs.each do |output, cfg|
              new_connections, add =
                if cfg.is_a?(Activity::DSL::Linear::Track)
                  [output_to_track(ctx, output, cfg), cfg.adds] # FIXME: why does Track have a {adds} field? we don't use it anywhere.
                elsif cfg.is_a?(Activity::DSL::Linear::Id)
                  [output_to_id(ctx, output, cfg.value), []]
                elsif cfg.is_a?(Activity::End)
                  _adds = []

                  end_id     = Linear.end_id(cfg)
                  end_exists = Insert.find_index(ctx[:sequence], end_id)

                  _adds      = [add_end(cfg, magnetic_to: end_id, id: end_id)] unless end_exists

                  [output_to_id(ctx, output, end_id), _adds]
                else
                  raise cfg.inspect
                end

              connections = connections.merge(new_connections)
              adds += add
            end

            ctx[:connections] = connections
            ctx[:adds]        = adds
          end

          def output_to_track(ctx, output, track)
            search_strategy = track.options[:wrap_around] ? :WrapAround : :Forward

            {output.value => [Linear::Search.method(search_strategy), track.color]}
          end

          def output_to_id(ctx, output, target)
            {output.value => [Linear::Search.method(:ById), target]}
          end

          # {#insert_task} options to add another end.
          def add_end(end_event, magnetic_to:, id:)

            options = Path::DSL.append_end_options(task: end_event, magnetic_to: magnetic_to, id: id)
            row     = Linear::Sequence.create_row(**options)

            {
              row:    row,
              insert: row[3][:sequence_insert]
            }
          end

          # Output(Signal, :semantic) => Id()
          def normalize_outputs_from_dsl(ctx, non_symbol_options:, outputs:, **)
            output_configs = non_symbol_options.find_all{ |k,v| k.kind_of?(Activity::Output) }
            return unless output_configs.any?

            dsl_options = {}

            output_configs.collect do |output, cfg| # {cfg} = Track(:success)
              outputs     = outputs.merge(output.semantic => output)
              dsl_options = dsl_options.merge(Linear.Output(output.semantic) => cfg)
            end

            ctx[:outputs]            = outputs
            ctx[:non_symbol_options] = non_symbol_options.merge(dsl_options)
          end

          # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
          def input_output_extensions(ctx, non_symbol_options:, **)
            input_exts  = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::In) }
            output_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Out) }
            inject_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Inject) }

            return unless input_exts.any? || output_exts.any? || inject_exts.any?

            ctx[:injects] = inject_exts
            ctx[:input_filters] = input_exts
            ctx[:output_filters] = output_exts # DISCUSS: naming
          end

          def input_output_dsl(ctx, extensions: [], input_filters: nil, output_filters: nil, injects: nil, **)
            config = ctx.select { |k,v| [:input, :output, :output_with_outer_ctx, :inject].include?(k) } # TODO: optimize this, we don't have to go through the entire hash.
            config = config.merge(input_filters: input_filters)   if input_filters
            config = config.merge(output_filters: output_filters) if output_filters # TODO: hm, is this nice code?

            config = config.merge(injects: injects) if injects

            return unless config.any? # no :input/:output/:inject/Input()/Output() passed.

            ctx[:extensions] = extensions + [Linear.VariableMapping(**config)]
          end

          # Currently, the {:inherit} option copies over {:connections} from the original step
          # and merges them with the (prolly) connections passed from the user.
          def inherit_option(ctx, inherit: false, sequence:, id:, extensions: [], **)
            return unless inherit

            index = Linear::Insert.find_index(sequence, id)
            row   = sequence[index] # from this row we're inheriting options.

            ctx[:connections] = get_inheritable_connections(ctx, row[3][:connections])
            ctx[:extensions]  = Array(row[3][:extensions]) + Array(extensions)
          end

          # return connections from {parent} step which are supported by current step
          private def get_inheritable_connections(ctx, parent_connections)
            return parent_connections unless ctx[:outputs]

            parent_connections.slice(*ctx[:outputs].keys)
          end

          # TODO: make this extendable!
          def cleanup_options(ctx, flow_options)
            # new_ctx = ctx.reject { |k, v| [:connections, :outputs, :end_id, :step_interface_builder, :failure_end, :track_name, :sequence].include?(k) }
            new_ctx = ctx.reject { |k, v| [:outputs, :end_id, :step_interface_builder, :failure_end, :track_name, :sequence, :non_symbol_options].include?(k) }

            return new_ctx, flow_options
          end
        end

      end # Normalizer
    end
  end
end
