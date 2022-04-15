module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizers are linear activities that process and normalize the options from a specific DSL call,
        # such as `#step` or `#pass`. All defaulting should happen through the normalizer. An invoked
        # normalizer produces an options hash that has to contain an [:adds] key with a ADDS structure usable
        # for {Sequence.apply_adds}.
        #
        # They're usually invoked from {Strategy#invoke_normalizer_for!}, which is called from {Path#step},
        # {Railway#pass}, etc.
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
          # The generic normalizer not tied to `step` or friends.
          def Normalizer#(pipeline)
            pipeline = TaskWrap::Pipeline.new(
              {
                "activity.normalize_step_interface"       => Normalizer.Task(method(:normalize_step_interface)),      # first
                "activity.normalize_for_macro"            => Normalizer.Task(method(:merge_user_options)),
                "activity.normalize_normalizer_options"   => Normalizer.Task(method(:merge_normalizer_options)),
                "activity.normalize_non_symbol_options"   => Normalizer.Task(method(:normalize_non_symbol_options)),
                "activity.normalize_context"              => method(:normalize_context),
                "activity.normalize_id"                   => Normalizer.Task(method(:normalize_id)),
                "activity.normalize_override"             => Normalizer.Task(method(:normalize_override)),
                "activity.wrap_task_with_step_interface"  => Normalizer.Task(method(:wrap_task_with_step_interface)),

                "activity.inherit_option"                 => Normalizer.Task(method(:inherit_option)),
                "activity.sequence_insert"                => Normalizer.Task(method(:normalize_sequence_insert)),
                "activity.normalize_duplications"         => Normalizer.Task(method(:normalize_duplications)),

                "activity.path_helper.forward_block"       => Normalizer.Task(Helper::Path::Normalizer.method(:forward_block_for_path_branch)),     # forward the "global" block
                "activity.path_helper.path_to_track"       => Normalizer.Task(Helper::Path::Normalizer.method(:convert_paths_to_tracks)),
                "activity.normalize_outputs_from_dsl"     => Normalizer.Task(method(:normalize_outputs_from_dsl)),     # Output(Signal, :semantic) => Id()
                "activity.normalize_connections_from_dsl" => Normalizer.Task(method(:normalize_connections_from_dsl)),
                "activity.input_output_extensions"        => Normalizer.Task(method(:input_output_extensions)),
                "activity.input_output_dsl"               => Normalizer.Task(method(:input_output_dsl)),


                "activity.wirings"                            => Normalizer.Task(method(:compile_wirings)),

                # TODO: make this a "Subprocess":
                "activity.compile_data" => Normalizer.Task(method(:compile_data)),
                "activity.create_row" => Normalizer.Task(method(:create_row)),
                "activity.create_add" => Normalizer.Task(method(:create_add)),
                "activity.create_adds" => Normalizer.Task(method(:create_adds)),
              }.to_a
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
          def merge_user_options(ctx, options:, user_options:, **)
            # {options} are either a <#task> or {} from macro
            ctx[:options] = options.merge(user_options) # Note that the user options are merged over the macro options.
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

          # Processes {:before,:after,:replace,:delete} options and
          # defaults to {before: "End.success"} which, yeah.
          def normalize_sequence_insert(ctx, end_id:, **)
            insertion = ctx.keys & sequence_insert_options.keys
            insertion = insertion[0]   || :before
            target    = ctx[insertion] || end_id

            insertion_method = sequence_insert_options[insertion]

            ctx[:sequence_insert] = [Linear::Insert.method(insertion_method), target]
          end

          # @private
          def sequence_insert_options
            {
              :before  => :Prepend,
              :after   => :Append,
              :replace => :Replace,
              :delete  => :Delete,
            }
          end

          def normalize_duplications(ctx, replace: false, **)
            return if replace

            raise_on_duplicate_id(ctx, **ctx)
            clone_duplicate_activity(ctx, **ctx) # DISCUSS: mutates {ctx}.
          end

          # @private
          def raise_on_duplicate_id(ctx, id:, sequence:, **)
            raise "ID #{id} is already taken. Please specify an `:id`." if sequence.find { |row| row[3][:id] == id }
          end

          # @private
          def clone_duplicate_activity(ctx, task:, sequence:, **)
            return unless task.is_a?(Class)

            ctx[:task] = task.clone if sequence.find { |row| row[1] == task }
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

          # Process {Output(:semantic) => target} and make them {:connections}.
          def normalize_connections_from_dsl(ctx, connections:, adds:, non_symbol_options:, sequence:, normalizers:, **)
            # Find all {Output() => Track()/Id()/End()}
            output_configs = non_symbol_options.find_all{ |k,v| k.kind_of?(Linear::OutputSemantic) }
            return unless output_configs.any?

            # DISCUSS: how could we add another magnetic_to to an end?
            output_configs.each do |output, cfg|
              new_connections, add =
                if cfg.is_a?(Linear::Track)
                  [output_to_track(ctx, output, cfg), cfg.adds] # FIXME: why does Track have a {adds} field? we don't use it anywhere.
                elsif cfg.is_a?(Linear::Id)
                  [output_to_id(ctx, output, cfg.value), []]
                elsif cfg.is_a?(Activity::End)
                  end_id     = Activity::Railway.end_id(**cfg.to_h)
                  end_exists = Insert.find_index(ctx[:sequence], end_id)

                  _adds = end_exists ? [] : add_terminus(cfg, id: end_id, sequence: sequence, normalizers: normalizers)

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

          # Returns ADDS for the new terminus.
          def add_terminus(end_event, id:, sequence:, normalizers:)
            step_options = Linear::State.invoke_normalizer_for(:terminus, end_event, {id: id}, sequence: sequence, normalizer_options: {}, normalizers: normalizers)

            step_options[:adds]
          end

          # Output(Signal, :semantic) => Id()
          def normalize_outputs_from_dsl(ctx, non_symbol_options:, outputs:, **)
            output_configs = non_symbol_options.find_all{ |k,v| k.kind_of?(Activity::Output) }
            return unless output_configs.any?

            dsl_options = {}

            output_configs.collect do |output, cfg| # {cfg} = Track(:success)
              outputs     = outputs.merge(output.semantic => output)
              dsl_options = dsl_options.merge(Linear::Strategy.Output(output.semantic) => cfg)
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

          def create_row(ctx, task:, wirings:, magnetic_to:, data:, **)
            ctx[:row] = Sequence.create_row(task: task, magnetic_to: magnetic_to, wirings: wirings, **data)
          end

          def create_add(ctx, row:, sequence_insert:, **)
            ctx[:add] = {row: row, insert: sequence_insert}
          end

          def create_adds(ctx, add:, adds:, **)
            ctx[:adds] = [add] + adds
          end

          # TODO: document DataVariable() => :name
          # Compile data that goes into the sequence row.
          def compile_data(ctx, default_variables_for_data: [:id, :dsl_track, :connections, :extensions, :stop_event], non_symbol_options:, **)
            variables_for_data = non_symbol_options.find_all { |k,v| k.instance_of?(Linear::DataVariableName) }.collect { |k,v| Array(v) }.flatten

            ctx[:data] = (default_variables_for_data + variables_for_data).collect { |key| [key, ctx[key]] }.to_h
          end
        end

      end # Normalizer
    end
  end
end
