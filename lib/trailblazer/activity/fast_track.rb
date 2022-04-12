module Trailblazer
  class Activity
    def self.FastTrack(options)
      Class.new(FastTrack) do
        initialize!(Railway::DSL::State.build(**FastTrack::DSL.OptionsForState(**options)))
      end
    end

    # Implementation module that can be passed to `Activity()`.
    class FastTrack
      Linear = Activity::DSL::Linear

      # Termini
      module End
        class FailFast < Railway::End::Failure; end
        class PassFast < Railway::End::Success; end
      end

      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        module_function

        def Normalizer(base_normalizer=Trailblazer::Activity::Railway::DSL.Normalizer())
          TaskWrap::Pipeline.prepend(
            base_normalizer,
            "activity.wirings",

            {
              "fast_track.pass_fast_option"  => Linear::Normalizer.Task(method(:pass_fast_option)),
              "fast_track.fail_fast_option"  => Linear::Normalizer.Task(method(:fail_fast_option)),
              "fast_track.fast_track_option" => Linear::Normalizer.Task(method(:fast_track_option)),
            }
          )
        end

        def NormalizerForFail
          pipeline = Normalizer(Railway::DSL.NormalizerForFail())

          TaskWrap::Pipeline.prepend(
            pipeline,
            "activity.wirings",

            {
              "fast_track.fail_fast_option_for_fail"  => Linear::Normalizer.Task(method(:fail_fast_option_for_fail)),
            }
          )
        end

        def NormalizerForPass
          pipeline = Normalizer(Railway::DSL.NormalizerForPass())

          TaskWrap::Pipeline.prepend(
            pipeline,
            "activity.wirings",

            {
              "fast_track.pass_fast_option_for_pass"  => Linear::Normalizer.Task(method(:pass_fast_option_for_pass)),
            }
          )
        end

        def pass_fast_option(ctx, **)
          ctx = merge_connections_for!(ctx, :pass_fast, :success, **ctx)

          ctx = merge_connections_for!(ctx, :pass_fast, :pass_fast, :pass_fast, **ctx)
          ctx = merge_outputs_for!(ctx,
            {pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast)},
            **ctx
          )
        end

        def pass_fast_option_for_pass(ctx, **)
          ctx = merge_connections_for!(ctx, :pass_fast, :failure, **ctx)
          ctx = merge_connections_for!(ctx, :pass_fast, :success, **ctx)
        end

        def fail_fast_option(ctx, **)
          ctx = merge_connections_for!(ctx, :fail_fast, :failure, **ctx)

          ctx = merge_connections_for!(ctx, :fail_fast, :fail_fast, :fail_fast, **ctx)
          ctx = merge_outputs_for!(ctx,
            {fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast)},
            **ctx
          )
        end

        def fail_fast_option_for_fail(ctx, **)
          ctx = merge_connections_for!(ctx, :fail_fast, :failure, **ctx)
          ctx = merge_connections_for!(ctx, :fail_fast, :success, **ctx)
        end

        def fast_track_option(ctx, fast_track: false, **)
          return unless fast_track

          ctx = merge_connections_for!(ctx, :fast_track, :fail_fast, :fail_fast, **ctx)
          ctx = merge_connections_for!(ctx, :fast_track, :pass_fast, :pass_fast, **ctx)

          ctx = merge_outputs_for!(ctx,
            {pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast),
                        fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast)},
            **ctx
          )
        end

        def merge_connections_for!(ctx, option_name, semantic, magnetic_to=option_name, connections:, **)
          return ctx unless ctx[option_name]

          ctx[:connections] = connections.merge(semantic => [Linear::Search.method(:Forward), magnetic_to])
          ctx
        end

        def merge_outputs_for!(ctx, new_outputs, outputs:, **)
          ctx[:outputs] = new_outputs.merge(outputs)
          ctx
        end

        def initial_sequence(initial_sequence:, fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **)
          sequence = initial_sequence

          sequence = Linear::DSL.append_terminus(sequence, fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast", normalizers: Normalizers)
          sequence = Linear::DSL.append_terminus(sequence, pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast", normalizers: Normalizers)
        end

        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::State::Normalizer.new(
          step: FastTrack::DSL.Normalizer(),
          fail: FastTrack::DSL.NormalizerForFail(),
          pass: FastTrack::DSL.NormalizerForPass(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        def self.OptionsForState(normalizers: Normalizers, **options)
          options = Railway::DSL.OptionsForState(**options).
              merge(normalizers: normalizers)

          initial_sequence = FastTrack::DSL.initial_sequence(**options)

          {
            **options,
            initial_sequence: initial_sequence,
          }
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

      include Activity::DSL::Linear::Helper
      extend Activity::DSL::Linear::Strategy

      initialize!(Railway::DSL::State.build(**DSL.OptionsForState()))
    end # FastTrack
  end
end
