module Trailblazer
  class Activity
    module DSL
      module Feature
        module Inherit
          module Normalizer
            module_function

            def record_options(ctx, flow_options, _, id:, sequence:, **)
              # filter out canonical options, this is a bit half-assed and purely to save us from filling up dev memory with a million {sequence} instances.
              options_to_record = ctx.keys - [:sequence, :first_arg, :node] # DISCUSS: do we really need this? it's going to be deleted anyway, at finalize time.

              recorded_options = ctx.slice(*options_to_record)

              ctx = ctx.merge(
                Data.Variable => [:recorded_options],
                recorded_options: recorded_options
              )

              return ctx, flow_options
            end

            def replay_options(ctx, flow_options, _, sequence:, inherit: false, **)
              return ctx, flow_options unless inherit

              replaced_id = ctx.fetch(:replace)

              recorded_options = sequence.nodes.fetch(replaced_id).data[:recorded_options]

              ctx = recorded_options.merge(ctx) # DISCUSS: test that we merge og over recorded.

              return ctx, flow_options
            end

            module Node
              Record = Circuit::Node[Normalizer.method(:record_options), Circuit::Task::Adapter::LibInterface]
              Replay = Circuit::Node[Normalizer.method(:replay_options), Circuit::Task::Adapter::LibInterface]
            end
          end
        end
      end # Feature
    end
  end
end
