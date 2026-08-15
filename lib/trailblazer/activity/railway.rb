module Trailblazer
  class Activity
    def self.Railway(track_name: :success, normalizers: Railway::NORMALIZERS, &block)
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: :failure,
            outputs: {},
          },
          left: {
            magnetic_to: :failure,
            track_name: :failure,
            failure_track_name: :failure,
            outputs: {}
          },
          pass: {
            magnetic_to: track_name,
            track_name: track_name,
            failure_track_name: track_name,
            outputs: {}
          }
        }
      )

      options_for_terminus = { # TODO: get from Path.
        task:        success_terminus = Trailblazer::Activity::Terminus::Success.new(semantic: track_name),
        wirings:     Path.wirings_for_terminus(signal: success_terminus, semantic: track_name),
        id:          DSL.id_for_terminus(semantic: track_name),
        magnetic_to: track_name
      }

      options_for_failure_terminus = {
        task:        failure_terminus = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure),
        wirings:     Path.wirings_for_terminus(signal: failure_terminus, semantic: :failure),
        id:          DSL.id_for_terminus(semantic: :failure),
        magnetic_to: :failure
      }

      activity, _ = builder.() do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
        step **DSL.options_for_terminus_step(semantic: :failure, terminus_class: Terminus::Failure),
          adds_insertion_args: [:after]
      end

      return activity, builder
    end

    class Railway < DSL::Topology
      extend DSL::Left
      extend DSL::Pass

      NORMALIZERS = {
        step: Path::Normalizer::Step,
        left: Path::Normalizer::Step,
        pass: Path::Normalizer::Step
      }.freeze

      config.activity, config.builder = Activity.Railway() # Activity::Railway is just a simple, pre-configured frontend.
    end
  end
end
