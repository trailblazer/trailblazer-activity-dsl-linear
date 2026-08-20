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

              # if strict
              #   options.merge!(
              #     outputs.collect { |output| [Normalizer::OutputTuples::Output::Semantic.new(output.semantic, true), Track(output.semantic)] }.to_h
              #   )
              # end

              {
                task:       activity,
                outputs:    outputs,#.collect { |output| [output.semantic, output] }.to_h,
                subprocess: true,
                adapter:    Circuit::Processor,
              }
            end
          end
        end
      end # Feature
    end
  end
end
