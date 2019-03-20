module Trailblazer
  class Activity
    def self.FastTrack(options={})
      FastTrack.new(FastTrack, options)
    end

    # Implementation module that can be passed to `Activity[]`.
    class FastTrack < Trailblazer::Activity
      Linear = Activity::DSL::Linear

      # Signals
      FailFast = Class.new(Signal)
      PassFast = Class.new(Signal)

      module DSL
        module_function
        Right = Trailblazer::Activity::Right

        def normalizer
          step_options(Trailblazer::Activity::Railway::DSL.normalizer)
        end

        def normalizer_for_fail
          step_options(Trailblazer::Activity::Railway::DSL.normalizer_for_fail)
        end

        def step_options(sequence)
          Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            "fast_track.pass_fast_option"  => method(:pass_fast_option),
            "fast_track.fail_fast_option"  => method(:fail_fast_option),
            "fast_track.fast_track_option" => method(:fast_track_option),
          )
        end

        def pass_fast_option((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :pass_fast, :success)

          return Right, [ctx, flow_options]
        end

        def fail_fast_option((ctx, flow_options), *)
          ctx = merge_connections_for(ctx, ctx, :fail_fast, :failure)

          return Right, [ctx, flow_options]
        end

        def fast_track_option((ctx, flow_options), *)
          return Right, [ctx, flow_options] unless ctx[:fast_track]

          ctx = merge_connections_for(ctx, ctx, :fast_track, :fail_fast, :fail_fast)
          ctx = merge_connections_for(ctx, ctx, :fast_track, :pass_fast, :pass_fast)

          ctx = ctx.merge(
            outputs: {
              pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast),
              fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast),
            }.merge(ctx[:outputs])
          )

          return Right, [ctx, flow_options]
        end

        def merge_connections_for(ctx, options, option_name, semantic, magnetic_to=option_name)
          return ctx unless options[option_name]

          connections  = ctx[:connections].merge(semantic => [Linear::Search.method(:Forward), magnetic_to])
          ctx          = ctx.merge(connections: connections)
        end



        def initial_sequence(initial_sequence:, **)
          sequence = initial_sequence

          sequence = Path::DSL.append_end(sequence, task: Activity::End.new(semantic: :fail_fast), magnetic_to: :fail_fast, id: "End.fail_fast")
          sequence = Path::DSL.append_end(sequence, task: Activity::End.new(semantic: :pass_fast), magnetic_to: :pass_fast, id: "End.pass_fast")
        end
      end # DSL

      # This is slow and should be done only once at compile-time,
      # DISCUSS: maybe make this a function?
      # These are the normalizers for an {Activity}, to be injected into a State.
      Normalizers = Linear::State::Normalizer.new(
        step:  Linear::Normalizer.activity_normalizer( FastTrack::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        fail: FastTrack::DSL.normalizer_for_fail,
      )


      def self.OptionsForState(normalizers: Normalizers, **options)
        options = Railway::DSL.OptionsForState(options).
            merge(normalizers: normalizers)

        initial_sequence = FastTrack::DSL.initial_sequence(**options)

        {
          **options,
          initial_sequence: initial_sequence,
        }
      end
    end # options_for_state
  end
end
