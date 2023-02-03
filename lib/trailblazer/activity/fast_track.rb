module Trailblazer
  class Activity
    # Implementation of the "FastTrack" layout that is also used for `Operation`.
    class FastTrack < Activity::DSL::Linear::Strategy

      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer(prepend_to_default_outputs: [], base_normalizer_builder: Railway::DSL.method(:Normalizer))
          fast_track_output_steps = {
            "fast_track.pass_fast_output" => Linear::Normalizer.Task(method(:add_pass_fast_output)),
            "fast_track.fail_fast_output" => Linear::Normalizer.Task(method(:add_fail_fast_output)),
            "fast_track.fast_track_outputs" => Linear::Normalizer.Task(method(:add_fast_track_outputs)),
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          step_normalizer = base_normalizer_builder.call( # E.g Railway::DSL.NormalizerForPass.
            prepend_to_default_outputs: [fast_track_output_steps, *prepend_to_default_outputs]
          )

          normalizer = Linear::Normalizer.prepend_to(
            step_normalizer,
            "activity.wirings",

            {
              "fast_track.pass_fast_option"  => Linear::Normalizer.Task(method(:pass_fast_option)),
              "fast_track.fail_fast_option"  => Linear::Normalizer.Task(method(:fail_fast_option)),
              "fast_track.fast_track_option"  => Linear::Normalizer.Task(method(:add_fast_track_connections)),

            }
          )
        end

        def NormalizerForFail
          pipeline = Normalizer(base_normalizer_builder: Railway::DSL.method(:NormalizerForFail))

          Linear::Normalizer.prepend_to(
            pipeline,
            "activity.wirings",

            {
              "fast_track.fail_fast_option_for_fail"  => Linear::Normalizer.Task(method(:fail_fast_option_for_fail)),
            }
          )
        end

        def NormalizerForPass
          pipeline = Normalizer(base_normalizer_builder: Railway::DSL.method(:NormalizerForPass))

          Linear::Normalizer.prepend_to(
            pipeline,
            "activity.wirings",

            {
              "fast_track.pass_fast_option_for_pass"  => Linear::Normalizer.Task(method(:pass_fast_option_for_pass)),
            }
          )
        end

        def add_pass_fast_output(ctx, outputs:, pass_fast: nil, **)
          return unless pass_fast

          ctx[:outputs] = PASS_FAST_OUTPUT.merge(outputs)
        end

        def add_fail_fast_output(ctx, outputs:, fail_fast: nil, **)
          return unless fail_fast

          ctx[:outputs] = FAIL_FAST_OUTPUT.merge(outputs)
        end

        def add_fast_track_outputs(ctx, outputs:, fast_track: nil, **)
          return unless fast_track

          ctx[:outputs] = FAIL_FAST_OUTPUT.merge(PASS_FAST_OUTPUT).merge(outputs)
        end

        PASS_FAST_OUTPUT = {pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast)}
        FAIL_FAST_OUTPUT = {fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast)}

        def add_fast_track_connections(ctx, fast_track: nil, **)
          # return unless fast_track

          ctx = merge_connections_for!(ctx, :fast_track, :pass_fast, :pass_fast, **ctx)
          ctx = merge_connections_for!(ctx, :fast_track, :fail_fast, :fail_fast, **ctx)
        end

        def pass_fast_option(ctx, **)
          ctx = merge_connections_for!(ctx, :pass_fast, :success, **ctx)

          ctx = merge_connections_for!(ctx, :pass_fast, :pass_fast, :pass_fast, **ctx)
        end

        def pass_fast_option_for_pass(ctx, **)
          ctx = merge_connections_for!(ctx, :pass_fast, :failure, **ctx)
          ctx = merge_connections_for!(ctx, :pass_fast, :success, **ctx)
        end

        def fail_fast_option(ctx, **)
          ctx = merge_connections_for!(ctx, :fail_fast, :failure, **ctx)

          ctx = merge_connections_for!(ctx, :fail_fast, :fail_fast, :fail_fast, **ctx)
        end

        def fail_fast_option_for_fail(ctx, **)
          ctx = merge_connections_for!(ctx, :fail_fast, :failure, **ctx)
          ctx = merge_connections_for!(ctx, :fail_fast, :success, **ctx)
        end

        def merge_connections_for!(ctx, option_name, semantic, magnetic_to=option_name, connections:, **)
          return ctx unless ctx[option_name]

          ctx[:connections] = connections.merge(semantic => [Linear::Sequence::Search.method(:Forward), magnetic_to])
          ctx
        end

        # Normalizer pipelines taking care of processing your DSL options.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step: FastTrack::DSL.Normalizer(),
          fail: FastTrack::DSL.NormalizerForFail(),
          pass: FastTrack::DSL.NormalizerForPass(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        def options_for_sequence_build(fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **options)
          fail_fast_terminus_options = [fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast", normalizers: Normalizers]
          past_fast_terminus_options = [pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast", normalizers: Normalizers]

          railway_options, railway_termini = Railway::DSL.options_for_sequence_build(**options)

          return railway_options, railway_termini + [fail_fast_terminus_options, past_fast_terminus_options]
        end
      end # DSL

      class << self
        private def fail(*args, &block)
          recompile_activity_for(:fail, *args, &block) # from Path::Strategy
        end

        private def pass(*args, &block)
          recompile_activity_for(:pass, *args, &block) # from Path::Strategy
        end
      end

      compile_strategy!(DSL, normalizers: DSL::Normalizers)
    end # FastTrack

    def self.FastTrack(**options, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(FastTrack, **options, &block)
    end
  end
end
