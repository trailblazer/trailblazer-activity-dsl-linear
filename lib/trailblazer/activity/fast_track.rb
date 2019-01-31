module Trailblazer
  class Activity
    def self.FastTrack(options={})
      FastTrack.new(FastTrack, options)
    end

    # Implementation module that can be passed to `Activity[]`.
    class FastTrack < Trailblazer::Activity
      def self.config
        Railway.config.merge(
          builder_class:  Magnetic::Builder::FastTrack,
          extend:          [
            DSL.def_dsl(:step, Magnetic::Builder::FastTrack, :StepPolarizations),
            DSL.def_dsl(:fail, Magnetic::Builder::FastTrack, :FailPolarizations),
            DSL.def_dsl(:pass, Magnetic::Builder::FastTrack, :PassPolarizations),
            DSL.def_dsl(:_end, Magnetic::Builder::Path,      :EndEventPolarizations), # TODO: TEST ME
          ],
        )
      end

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



        def initial_sequence
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Railway::DSL.initial_sequence

          sequence = Path::DSL.append_end(Activity::End.new(semantic: :fail_fast), sequence, magnetic_to: :fail_fast, id: "End.fail_fast")
          sequence = Path::DSL.append_end(Activity::End.new(semantic: :pass_fast), sequence, magnetic_to: :pass_fast, id: "End.pass_fast")
        end
      end # DSL

      def self.initial_sequence # FIXME: 2BRM
        DSL.initial_sequence
      end
    end
  end
end
