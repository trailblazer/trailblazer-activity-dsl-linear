module Trailblazer
  class Activity
    def self.Railway(normalizers: Railway.config.builder.normalizers, **options, &block)
      Path(normalizers: normalizers, **options, &block)
    end

    class Railway < DSL::Topology
      extend DSL::Left
      extend DSL::Pass
      extend DSL::Feature::Terminus

      options = {
        step: {
          magnetic_to: :success,
          track_name: :success,
          failure_track_name: :failure,
          outputs: DSL::RIGHT_LEFT_OUTPUTS,
        },
        left: {
          magnetic_to: :failure,
          track_name: :failure,
          failure_track_name: :failure,
          outputs: DSL::RIGHT_LEFT_OUTPUTS,
        },
        pass: {
          magnetic_to: :success,
          track_name: :success,
          failure_track_name: :success,
          outputs: DSL::RIGHT_LEFT_OUTPUTS,
        }
      }

      normalizers = {
        left: Path.config.builder.normalizers[:step],
        pass: Path.config.builder.normalizers[:step]
      }

      # By cloning Path's builder, we "inherit" the imported helpers.
      railway_builder = Path.config.builder.clone( # we inherit everything (set up sequence, helpers, normalizers)
        defaults: {}
      )
      railway_builder.default_options = railway_builder.default_options.merge(options) # DISCUSS: not entirely sure this must be covered by #clone?
      railway_builder.normalizers = railway_builder.normalizers.merge(normalizers) # DISCUSS: not entirely sure this must be covered by #clone?

      config.activity, config.builder = Activity.Path(builder: railway_builder) do
        # we inherit the {:success} terminus from cloning Path's builder (and obviously, its Sequence).
        step **DSL.options_for_terminus_step(semantic: :failure, terminus_class: Terminus::Failure)
      end

      # Trailblazer::Developer.puts(config.builder.normalizers[:step])
      extend Path.config.helper_forwarder # forward Output() and friends to {builder}.
    end
  end
end
