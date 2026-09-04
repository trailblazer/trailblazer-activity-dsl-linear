module Trailblazer
  class Activity
    def self.Railway(normalizers: Railway.config.builder.normalizers, helpers: nil, adds:, **default_options,  &block)
      default_options = Railway.default_options_for_builder(**default_options)

      activity, builder, helper = DSL.Topology(normalizers: normalizers, adds: adds, default_options: default_options, helper_forwarder: Path.config.helper_forwarder, helpers: helpers) do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
        step **DSL.options_for_terminus_step(semantic: :failure, terminus_class: Terminus::Failure)
      end

      activity, _ = builder.(&block) if block_given? # FIXME: do that in Topology!    implement for Railway and FastTrack?

      return activity, builder, helper
    end

    class Railway < DSL::Topology
      extend DSL::Left
      extend DSL::Pass
      extend DSL::Feature::Terminus

      def self.default_options_for_builder(track_name: :success, **options)
        {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,
            **options,
          },
          left: {
            magnetic_to: :failure,
            track_name: :failure,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,
            **options,
          },
          pass: {
            magnetic_to: track_name,
            track_name: track_name,
            failure_track_name: track_name,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,
            **options, # DISCUSS: do we need that?
          }
        }
      end

      options = {
        # default_options: default_options_for_builder,
        normalizers: {
          step: Path.config.builder.normalizers[:step],
          left: Path.config.builder.normalizers[:step],
          pass: Path.config.builder.normalizers[:step]
        },
        adds: [],
      }

      config.activity, config.builder, config.helper_forwarder = Activity.Railway(**options) # Activity::Railway is just a simple, pre-configured frontend.
      # Trailblazer::Developer.puts(config.builder.normalizers[:step])
      extend config.helper_forwarder # forward Output() and friends to {builder}.
    end
  end
end
