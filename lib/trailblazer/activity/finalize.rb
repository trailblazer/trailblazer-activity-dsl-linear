module Trailblazer
  class Activity
    module Finalize
      class Builder < DSL::Builder
        # We're removing the compile_activity step
        def call(&block)
          sequence = update_sequence!(&block)

          return nil, sequence
        end
      end

      def finalize
        circuit, outputs = config.builder.compile_activity

        config.circuit, config.outputs = circuit, outputs
      end
    end
  end
end
