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
        activity = config.builder.compile_activity

        config.activity = activity
      end
    end
  end
end
