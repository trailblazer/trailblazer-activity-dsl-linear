module Trailblazer
  class Activity
    def self.Railway(track_name: :success, normalizers: Railway::NORMALIZERS, &block)
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: Railway.default_options(track_name: track_name)
      )

      activity, _ = builder.() do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
        step **DSL.options_for_terminus_step(semantic: :failure, terminus_class: Terminus::Failure)
      end

      return activity, builder
    end

    class Railway < DSL::Topology
      extend DSL::Left
      extend DSL::Pass
      extend DSL::Feature::Terminus

      NORMALIZERS = {
        step: Path::Normalizer::Step,
        left: Path::Normalizer::Step,
        pass: Path::Normalizer::Step
      }.freeze

      def self.default_options(track_name:)
        {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,
          },
          left: {
            magnetic_to: :failure,
            track_name: :failure,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS
          },
          pass: {
            magnetic_to: track_name,
            track_name: track_name,
            failure_track_name: track_name,
            outputs: DSL::RIGHT_LEFT_OUTPUTS
          }
        }
      end

      config.activity, config.builder = Activity.Railway() # Activity::Railway is just a simple, pre-configured frontend.
    end
  end
end
