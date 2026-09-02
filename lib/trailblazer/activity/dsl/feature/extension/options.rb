module Trailblazer
  class Activity
    module DSL
      module Feature
        module Extension
          module Options
            # Add custom step options as if they were a normalizer step.
            module Normalizer
              def self.evaluate_options_extensions(ctx, flow_options, signal, options_extensions:, **)
                ctx = options_extensions.inject(ctx) do |ctx, ext|
                  ctx, _flow_options = ext.(ctx, flow_options, signal, **ctx)

                  ctx
                end

                return ctx, flow_options
              end

              Node = Circuit::Node[method(:evaluate_options_extensions), Circuit::Task::Adapter::LibInterface]
            end
          end # Options
        end
      end
    end
  end
end


  # def compute_normalizer_extensions(ctx, flow_options, _, subprocess: false, task:, normalizer_extensions: nil, **)
  #             return ctx, flow_options if normalizer_extensions

  #             if subprocess
  #               # Activity subclasses maintain a field {:task_wrap_extensions} that can be used to expose the
  #           #   # taskWrap for the activity itself to an outer user, e.g. when being nested.
  #               normalizer_extensions = task.to_h[:fields].fetch(:normalizer_extensions)
  #             else
  #               normalizer_extensions = Strategy::INITIAL_NORMALIZER_EXTENSIONS
  #             end

  #             ctx = ctx.merge(normalizer_extensions: normalizer_extensions)

  #             return ctx, flow_options
  #           end
