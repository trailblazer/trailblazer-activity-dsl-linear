module Trailblazer
  class Activity
    module DSL
      module Feature
        module Extension
          module TaskWrap
            # DISCUSS: add other tW related logic here from Normalizer::Step?
            # This logic needs {:adds_for_task_wrap} to be present, and to be an array.
            # This option, however, is the concept of this very extension, so we can't default
            # :adds_for_task_wrap in the canonical normalizer.
            module Normalizer
              # Add third-party steps to the {:task_wrap_pipeline} for the currently
              # compiled step.
              def self.apply_adds_to_task_wrap_pipeline(ctx, flow_options, _, task_wrap_pipeline:, adds_for_task_wrap:, **)
                task_wrap_pipeline = Circuit::Adds.(task_wrap_pipeline, *adds_for_task_wrap)

                return ctx.merge(task_wrap_pipeline: task_wrap_pipeline), flow_options
              end

              Node = Circuit::Node[method(:apply_adds_to_task_wrap_pipeline), Circuit::Task::Adapter::LibInterface]
            end
          end # TaskWrap
        end
      end
    end
  end
end
