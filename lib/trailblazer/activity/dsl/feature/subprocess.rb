module Trailblazer
  class Activity
    module DSL
      module Feature
        module Subprocess
          module Helper
            def Subprocess(activity, patch: {}, strict: false)
              activity = Subprocess.apply_patches(activity, patch)

              outputs  = activity.to_h[:outputs]

              options = {}
              # if strict
              #   options =
              #     outputs.collect { |semantic, output|
              #       [Output(output.semantic), Track(output.semantic)]
              #     }.to_h
              # end

              {
                task:       activity,
                outputs:    outputs,
                subprocess: true,
                adapter:    Circuit::Processor,
                **options
              }
            end
          end

          # Simply apply the patches in the hash to {activity}, replacing activity
          # with every iteration.
          def self.apply_patches(activity, patches)
            patches.inject(activity) do |activity, (path, patch)|
              Patch.(activity, path, patch)
            end
          end
        end
      end # Feature
    end
  end
end
