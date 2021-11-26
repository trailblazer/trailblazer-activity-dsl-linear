module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizers are linear activities that process and normalize the options from a DSL call. They're
        # usually invoked from {Strategy#task_for}, which is called from {Path#step}, {Railway#pass}, etc.
        module Normalizer
          module_function

          #   activity_normalizer.([{options:, user_options:, normalizer_options: }])
          def activity_normalizer(sequence)
            seq = Path::DSL.prepend_to_path(
              sequence,

              {
              "activity.normalize_step_interface"       => TaskBuilder::Binary(method(:normalize_step_interface)),      # first
              "activity.normalize_for_macro"            => TaskBuilder::Binary(method(:merge_user_options)),
              "activity.normalize_normalizer_options"   => TaskBuilder::Binary(method(:merge_normalizer_options)),
              "activity.normalize_context"              => method(:normalize_context),
              "activity.normalize_id"                   => TaskBuilder::Binary(method(:normalize_id)),
              "activity.normalize_override"             => TaskBuilder::Binary(method(:normalize_override)),
              "activity.wrap_task_with_step_interface"  => TaskBuilder::Binary(method(:wrap_task_with_step_interface)), # last
              "activity.inherit_option"                 => TaskBuilder::Binary(method(:inherit_option)),
              },

              Linear::Insert.method(:Append), "Start.default"
            )

            seq = Trailblazer::Activity::Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
              seq,

              {
              "activity.normalize_outputs_from_dsl"     => method(:normalize_outputs_from_dsl),     # Output(Signal, :semantic) => Id()
              "activity.normalize_connections_from_dsl" => method(:normalize_connections_from_dsl),
              "activity.input_output_dsl"               => TaskBuilder::Binary(method(:input_output_dsl)), # FIXME: make this optional and allow to dynamically change normalizer steps
              },

              Linear::Insert.method(:Prepend), "path.wirings"
            )

            seq = Trailblazer::Activity::Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
              seq,

              {
              "activity.cleanup_options"     => method(:cleanup_options),
              },

              Linear::Insert.method(:Prepend), "End.success"
            )
# pp seq
            seq
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
            return true unless wrap_task

            ctx[:task] = step_interface_builder.(task)
          end

          def normalize_id(ctx, id: false, task:, **)
            ctx[:id] = id || task
            true # FIXME: why do we need this?
          end

          # {:override} really only makes sense for {step Macro(), {override: true}} where the {user_options}
          # dictate the overriding.
          def normalize_override(ctx, id:, override: false, **)
            return true unless override
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

          def normalize_context((ctx, flow_options), *)
            ctx = ctx[:options]

            return Trailblazer::Activity::Right, [ctx, flow_options]
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

          # Process {Output(:semantic) => target}.
          def normalize_connections_from_dsl((ctx, flow_options), *)
            new_ctx = ctx.reject { |output, cfg| output.kind_of?(Activity::DSL::Linear::OutputSemantic) }
            connections = new_ctx[:connections]
            adds        = new_ctx[:adds]

            # Find all {Output() => Track()/Id()/End()}
            (ctx.keys - new_ctx.keys).each do |output|
              cfg = ctx[output]

              new_connections, add =
                if cfg.is_a?(Activity::DSL::Linear::Track)
                  [output_to_track(ctx, output, cfg), cfg.adds]
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

            new_ctx = new_ctx.merge(connections: connections, adds: adds)

            return Trailblazer::Activity::Right, [new_ctx, flow_options]
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
          def normalize_outputs_from_dsl((ctx, flow_options), *)
            new_ctx = ctx.reject { |output, cfg| output.kind_of?(Activity::Output) }

            outputs     = ctx[:outputs]
            dsl_options = {}

            (ctx.keys - new_ctx.keys).collect do |output|
              cfg      = ctx[output] # e.g. Track(:success)

              outputs = outputs.merge(output.semantic => output)
              dsl_options = dsl_options.merge(Linear.Output(output.semantic) => cfg)
            end

            new_ctx = new_ctx.merge(outputs: outputs).merge(dsl_options)

            return Trailblazer::Activity::Right, [new_ctx, flow_options]
          end

          def input_output_dsl(ctx, extensions: [], **)
            config = ctx.select { |k,v| [:input, :output, :output_with_outer_ctx, :inject].include?(k) } # TODO: optimize this, we don't have to go through the entire hash.
            return true unless config.any? # no :input/:output/:inject passed.

            ctx[:extensions] = extensions + [Linear.VariableMapping(**config)]
          end

          # Currently, the {:inherit} option copies over {:connections} from the original step
          # and merges them with the (prolly) connections passed from the user.
          def inherit_option(ctx, inherit: false, sequence:, id:, extensions: [], **)
            return true unless inherit

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
          def cleanup_options((ctx, flow_options), *)
            # new_ctx = ctx.reject { |k, v| [:connections, :outputs, :end_id, :step_interface_builder, :failure_end, :track_name, :sequence].include?(k) }
            new_ctx = ctx.reject { |k, v| [:outputs, :end_id, :step_interface_builder, :failure_end, :track_name, :sequence].include?(k) }

            return Trailblazer::Activity::Right, [new_ctx, flow_options]
          end
        end

      end # Normalizer
    end
  end
end
