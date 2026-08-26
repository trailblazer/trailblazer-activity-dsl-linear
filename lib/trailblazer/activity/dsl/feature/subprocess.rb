module Trailblazer
  class Activity
    module DSL
      module Feature
        module Subprocess
          module Helper
            # @param :strict If true, all outputs of {activity} will be wired to the track named after the
            #   output's semantic.
            def Subprocess(activity, patch: {}, strict: false)
              # activity = Linear::Patch.customize(activity, options: patch)

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
        end
      end # Feature
    end
  end
end
