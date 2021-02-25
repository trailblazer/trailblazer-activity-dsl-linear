module Trailblazer
  class Activity
    def self.FastTrack(options)
      Class.new(FastTrack) do
        initialize!(Railway::DSL::State.new(**FastTrack::DSL.OptionsForState(**options)))
      end
    end

    # Implementation module that can be passed to `Activity[]`.
    class FastTrack
      Linear = Activity::DSL::Linear

      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        module_function

        def normalizer
          step_options(Trailblazer::Activity::Railway::DSL.normalizer)
        end

        def normalizer_for_fail
          sequence = step_options(Trailblazer::Activity::Railway::DSL.normalizer_for_fail)

          Path::DSL.prepend_to_path(
            sequence,

            {
              "fast_track.fail_fast_option_for_fail"  => method(:fail_fast_option_for_fail),
            },
            Linear::Insert.method(:Prepend), "path.wirings"
          )
        end

        def normalizer_for_pass
          sequence = step_options(Trailblazer::Activity::Railway::DSL.normalizer_for_pass)

          Path::DSL.prepend_to_path(
            sequence,

            {
              "fast_track.pass_fast_option_for_pass"  => method(:pass_fast_option_for_pass),
            },
            Linear::Insert.method(:Prepend), "path.wirings"
          )
        end

        def step_options(sequence)
          Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            {
              "fast_track.pass_fast_option"  => method(:pass_fast_option),
              "fast_track.fail_fast_option"  => method(:fail_fast_option),
              "fast_track.fast_track_option" => method(:fast_track_option),
            },
            Linear::Insert.method(:Prepend), "path.wirings"
          )
        end

        def pass_fast_option((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :pass_fast, :success)

          ctx = merge_connections_for(ctx, ctx, :pass_fast, :pass_fast, :pass_fast)
          ctx = merge_outputs_for(ctx,
            pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast),
          )

          return Right, [ctx, flow_options]
        end

        def pass_fast_option_for_pass((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :pass_fast, :failure)
          ctx = merge_connections_for(ctx, ctx, :pass_fast, :success)

          return Right, [ctx, flow_options]
        end

        def fail_fast_option((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :fail_fast, :failure)

          ctx = merge_connections_for(ctx, ctx, :fail_fast, :fail_fast, :fail_fast)
          ctx = merge_outputs_for(ctx,
            fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast),
          )

          return Right, [ctx, flow_options]
        end

        def fail_fast_option_for_fail((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :fail_fast, :failure)
          ctx = merge_connections_for(ctx, ctx, :fail_fast, :success)

          return Right, [ctx, flow_options]
        end

        def fast_track_option((ctx, flow_options), *)
          return Right, [ctx, flow_options] unless ctx[:fast_track]

          ctx = merge_connections_for(ctx, ctx, :fast_track, :fail_fast, :fail_fast)
          ctx = merge_connections_for(ctx, ctx, :fast_track, :pass_fast, :pass_fast)

          ctx = merge_outputs_for(ctx,
            pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast),
            fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast),
          )

          return Right, [ctx, flow_options]
        end

        def merge_connections_for(ctx, options, option_name, semantic, magnetic_to=option_name)
          return ctx unless options[option_name]

          connections  = ctx[:connections].merge(semantic => [Linear::Search.method(:Forward), magnetic_to])
          ctx          = ctx.merge(connections: connections)
        end

        def merge_outputs_for(ctx, outputs)
          ctx = ctx.merge(
            outputs: outputs.merge(ctx[:outputs])
          )
        end

        def initial_sequence(initial_sequence:, fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **_o)
          sequence = initial_sequence

          sequence = Path::DSL.append_end(sequence, task: fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast")
          sequence = Path::DSL.append_end(sequence, task: pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast")
        end



        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::State::Normalizer.new(
          step: Linear::Normalizer.activity_normalizer( FastTrack::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          fail: Linear::Normalizer.activity_normalizer( FastTrack::DSL.normalizer_for_fail ),
          pass: Linear::Normalizer.activity_normalizer( FastTrack::DSL.normalizer_for_pass ),
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

      initialize!(Railway::DSL::State.new(**DSL.OptionsForState()))

    end # FastTrack
  end
end
