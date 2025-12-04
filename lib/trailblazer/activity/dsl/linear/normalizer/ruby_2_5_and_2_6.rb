module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # TODO: remove when we drop < Ruby 2.7.
          module Ruby2_5_and_2_6
            class Runner
              def self.call(task, ctx, flow_options, circuit_options)
                task.(ctx, flow_options, circuit_options, **NormalizerCtx.to_kwargs(ctx)) # return ctx, flow_options
              end
            end

            module CallNormalizer
              # Inject our patched runner into the normalizer call.
              def call_normalizer(normalizer, ctx, flow_options, runner: Runner)
                super
              end
            end

            class NormalizerCtx
              def self.to_kwargs(ctx)
                ctx.find_all { |k, v| k.is_a?(Symbol) }.to_h
              end
            end
          end # Ruby2_5_and_2_6

          # Monkey-patch!
          Normalizer.singleton_class.prepend(Ruby2_5_and_2_6::CallNormalizer)
        end
      end
    end
  end
end
