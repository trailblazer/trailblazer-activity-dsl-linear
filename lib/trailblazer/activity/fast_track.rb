module Trailblazer
  class Activity
    def self.FastTrack(**options, &block)
      Class.new(FastTrack) do
        compile_strategy!(FastTrack::DSL, **options)

        instance_exec(&block) if block_given?
      end
    end

    # Implementation of the "FastTrack" layout that is also used for `Operation`.
    class FastTrack < Activity::DSL::Linear::Strategy

      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer(base_normalizer=Trailblazer::Activity::Railway::DSL.Normalizer())
          Linear::Normalizer.prepend_to(
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

          Linear::Normalizer.prepend_to(
            pipeline,
            "activity.wirings",

            {
              "fast_track.fail_fast_option_for_fail"  => Linear::Normalizer.Task(method(:fail_fast_option_for_fail)),
            }
          )
        end

        def NormalizerForPass
          pipeline = Normalizer(Railway::DSL.NormalizerForPass())

          Linear::Normalizer.prepend_to(
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

          ctx[:connections] = connections.merge(semantic => [Linear::Sequence::Search.method(:Forward), magnetic_to])
          ctx
        end

        def merge_outputs_for!(ctx, new_outputs, outputs:, **)
          ctx[:outputs] = new_outputs.merge(outputs)
          ctx
        end

        def initial_sequence(sequence:, fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **)
          sequence = Path::DSL.append_terminus(sequence, fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast", normalizers: Normalizers)
          sequence = Path::DSL.append_terminus(sequence, pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast", normalizers: Normalizers)
        end

        # Normalizer pipelines taking care of processing your DSL options.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step: FastTrack::DSL.Normalizer(),
          fail: FastTrack::DSL.NormalizerForFail(),
          pass: FastTrack::DSL.NormalizerForPass(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        def self.OptionsForSequenceBuilder(normalizers: Normalizers, **options)

          options = Railway::DSL.OptionsForSequenceBuilder(**options).
              merge(normalizers: normalizers)

          initial_sequence = DSL.initial_sequence(**options)

          {
            **options,
            sequence: initial_sequence,
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

      compile_strategy!(DSL)
    end # FastTrack
  end
end
