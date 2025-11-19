module Trailblazer
  class Activity
    # Implementation of the "FastTrack" layout that is also used for `Operation`.
    class FastTrack < Activity::DSL::Linear::Strategy
      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        Linear = Activity::DSL::Linear
        # The connector logic needs to be run before Railway's connector logic:
        PREPEND_TO = "activity.path_helper.path_to_track"

        module_function

        def Normalizer(prepend_to_default_outputs: {}, base_normalizer_builder: Railway::DSL.method(:Normalizer))
          fast_track_output_steps = {
            "fast_track.pass_fast_output"     => method(:add_pass_fast_output),
            "fast_track.fail_fast_output"     => method(:add_fail_fast_output),
            "fast_track.fast_track_outputs"   => method(:add_fast_track_outputs),
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          step_normalizer = base_normalizer_builder.call( # E.g Railway::DSL.NormalizerForPass.
            prepend_to_default_outputs: fast_track_output_steps.merge(prepend_to_default_outputs)
          )

          _normalizer = Linear::Normalizer.prepend_to(
            step_normalizer,
            PREPEND_TO,
            {
              "fast_track.record_options"     => method(:record_options),
              "fast_track.pass_fast_option"   => method(:pass_fast_option),
              "fast_track.fail_fast_option"   => method(:fail_fast_option),
              "fast_track.fast_track_option"  => method(:add_fast_track_connectors),
            }
          )
        end

        module Fail
          module_function

          def Normalizer
            pipeline = DSL.Normalizer(base_normalizer_builder: Railway::DSL::Fail.method(:Normalizer))

            Linear::Normalizer.prepend_to(
              pipeline,
              PREPEND_TO,
              {
                "fast_track.fail_fast_option_for_fail"  => DSL.method(:fail_fast_option_for_fail),
              }
            )
          end
        end

        module Pass
          module_function

          def Normalizer
            pipeline = DSL.Normalizer(base_normalizer_builder: Railway::DSL::Pass.method(:Normalizer))

            Linear::Normalizer.prepend_to(
              pipeline,
              PREPEND_TO,
              {
                "fast_track.pass_fast_option_for_pass"  => DSL.method(:pass_fast_option_for_pass),
              }
            )
          end
        end

        # inherit: true
        RECORD_OPTIONS = [:pass_fast, :fail_fast, :fast_track]

        # *If* {fast_track: true} (or :pass_fast or :fail_fast), record it using Normalizer::Inherit mechanics.
        def record_options(ctx, flow_options, _, **)
          recorded_options =
            RECORD_OPTIONS.collect { |option| ctx.key?(option) ? [option, ctx[option]] : nil }
              .compact
              .to_h

          ctx = ctx.merge(
            Linear::Normalizer::Inherit.Record(recorded_options, type: :fast_track)
          )

          return ctx, flow_options
        end

        def add_pass_fast_output(ctx, flow_options, _, outputs:, pass_fast: nil, **)
          return ctx, flow_options unless pass_fast

          ctx = ctx.merge(outputs: PASS_FAST_OUTPUT.merge(outputs))

          return ctx, flow_options
        end

        def add_fail_fast_output(ctx, flow_options, _, outputs:, fail_fast: nil, **)
          return ctx, flow_options unless fail_fast

          ctx = ctx.merge(outputs: FAIL_FAST_OUTPUT.merge(outputs))

          return ctx, flow_options
        end

        def add_fast_track_outputs(ctx, flow_options, _, outputs:, fast_track: nil, **)
          return ctx, flow_options unless fast_track

          ctx = ctx.merge(outputs: FAIL_FAST_OUTPUT.merge(PASS_FAST_OUTPUT).merge(outputs))

          return ctx, flow_options
        end

        PASS_FAST_OUTPUT = {pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast)}
        FAIL_FAST_OUTPUT = {fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast)}

        def add_fast_track_connectors(ctx, flow_options, _, fast_track: nil, **)
          ctx = merge_connections_for(ctx, :fast_track, :pass_fast, :pass_fast)
          ctx = merge_connections_for(ctx, :fast_track, :fail_fast, :fail_fast)

          return ctx, flow_options
        end

        def pass_fast_option(ctx, flow_options, _, outputs:, **)
          ctx = merge_connections_for(ctx, :pass_fast, :success)

          ctx = merge_connections_for(ctx, :pass_fast, :pass_fast, :pass_fast) if outputs[:pass_fast]

          return ctx, flow_options
        end

        def pass_fast_option_for_pass(ctx, flow_options, _, **)
          ctx = merge_connections_for(ctx, :pass_fast, :failure)
          ctx = merge_connections_for(ctx, :pass_fast, :success)

          return ctx, flow_options
        end

        def fail_fast_option(ctx, flow_options, _, outputs:, **)
          ctx = merge_connections_for(ctx, :fail_fast, :failure)

          # DISCUSS: instead of checking outputs here, we could introduce something like Output(non_strict: true)
          ctx = merge_connections_for(ctx, :fail_fast, :fail_fast, :fail_fast) if outputs[:fail_fast]

          return ctx, flow_options
        end

        def fail_fast_option_for_fail(ctx, flow_options, _, **)
          ctx = merge_connections_for(ctx, :fail_fast, :failure)
          ctx = merge_connections_for(ctx, :fail_fast, :success)

          return ctx, flow_options
        end

        def merge_connections_for(ctx, option_name, semantic, magnetic_to = option_name, **)
          return ctx unless ctx[option_name]

          connector = {Linear::Normalizer::OutputTuples.Output(semantic) => Linear::Strategy.Track(magnetic_to)}

          connector.merge(ctx)
        end

        # Normalizer pipelines taking care of processing your DSL options.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step: FastTrack::DSL.Normalizer(),
          fail: FastTrack::DSL::Fail.Normalizer(),
          pass: FastTrack::DSL::Pass.Normalizer(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # Default options for build.
        def self.options_for_initialize(fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **options)
          options = Railway::DSL.options_for_initialize(**options)

          layout_instructions = options[:layout_instructions] + [
            [:terminus, task: fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast", after: nil],
            [:terminus, task: pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast", after: nil],
          ]

          normalizer_options = options[:normalizer_options].merge(fail_fast_end: fail_fast_end, pass_fast_end: pass_fast_end) # FIXME: do we need this?

          {
            layout_instructions: layout_instructions,
            normalizers: Normalizers,
            normalizer_options: normalizer_options
          }
        end

      end # DSL

      class << self
        private def fail(*args, &block)# FIXME: what about Railway?
          recompile_activity_for(:fail, *args, &block) # from Path::Strategy
        end
        alias left fail

        private def pass(*args, &block)
          recompile_activity_for(:pass, *args, &block) # from Path::Strategy
        end
      end

      compile_strategy!(DSL)
    end # FastTrack

    def self.FastTrack(**kws, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(FastTrack, **kws, &block)
    end
  end
end
