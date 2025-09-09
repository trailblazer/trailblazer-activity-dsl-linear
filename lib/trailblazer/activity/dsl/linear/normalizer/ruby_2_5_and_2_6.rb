module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # TODO: remove when we drop < Ruby 2.7.
          module Ruby2_5_and_2_6
            module Call
              def call(wrap_ctx, args)
                super(NormalizerCtx[wrap_ctx], args)
              end
            end

            class NormalizerCtx < Hash
              def to_hash
                symbol_options = find_all { |k, v| k.is_a?(Symbol) }.to_h

                symbol_options
              end
            end

            module Extensions
              def compile_normalizer_extensions(ctx, normalizer_extensions:, **)
                # pp normalizer_extensions
                normalizer_extensions.inject(ctx) do |ctx, ext|
                  ext.(ctx, **NormalizerCtx[ctx].to_hash)
                end
              end
            end
          end # Ruby2_5_and_2_6

          # Monkey-patch!
          TaskAdapter.prepend(Ruby2_5_and_2_6::Call)
          Extensions.singleton_class.prepend(Ruby2_5_and_2_6::Extensions)
        end
      end
    end
  end
end
