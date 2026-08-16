module Trailblazer
  class Activity
    def self.FastTrack(track_name: :success, normalizers: FastTrack::NORMALIZERS, &block)

      # DISCUSS: should we reuse the Railway builder?


      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: { # FIXME: use from Railway!
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,
          },
          left: {
            magnetic_to: :failure,
            track_name: :failure,
            failure_track_name: :failure,
            outputs: DSL::RIGHT_LEFT_OUTPUTS
          },
          pass: {
            magnetic_to: track_name,
            track_name: track_name,
            failure_track_name: track_name,
            outputs: DSL::RIGHT_LEFT_OUTPUTS
          }
        }
      )

      activity, _ = builder.() do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
        step **DSL.options_for_terminus_step(semantic: :failure, terminus_class: Terminus::Failure),
          adds_insertion_args: [:after]
        step **DSL.options_for_terminus_step(semantic: :pass_fast, terminus_class: FastTrack::Terminus::PassFast),
          adds_insertion_args: [:after]
        step **DSL.options_for_terminus_step(semantic: :fail_fast, terminus_class: FastTrack::Terminus::FailFast),
          adds_insertion_args: [:after]
      end

      return activity, builder
    end

    class FastTrack < DSL::Topology
      extend DSL::Left
      extend DSL::Pass

      module Normalizer
        Helper = DSL::Feature::OutputTuples::Helper

        module_function

        def add_pass_fast_tuple(ctx, flow_options, _, pass_fast: nil, **)
          return ctx, flow_options unless pass_fast

          return ctx.merge(Helper.Output(:success) => Helper.Track(:pass_fast)), flow_options
        end

        def add_fail_fast_tuple(ctx, flow_options, _, fail_fast: nil, **)
          return ctx, flow_options unless fail_fast

          return ctx.merge(Helper.Output(:failure) => Helper.Track(:fail_fast)), flow_options
        end

        circuit = Circuit::Builder.Circuit(
          [:add_pass_fast_tuple, method(:add_pass_fast_tuple)],
          [:add_fail_fast_tuple, method(:add_fail_fast_tuple)],
        )

        Node = Trailblazer::Circuit::Node[:bla_FIXME, circuit, Circuit::Processor]

        Step = Circuit::Adds.(
          Path::Normalizer::Step,
          [
            :normalize_fast_track_options, Node,
            :before, :normalize_wirings
          ]
        )
      end # Normalizer

      NORMALIZERS = {
        step: FastTrack::Normalizer::Step,
        left: FastTrack::Normalizer::Step,
        pass: FastTrack::Normalizer::Step
      }.freeze

      module Terminus
        PassFast = Class.new(Activity::Terminus::Success)
        FailFast = Class.new(Activity::Terminus::Failure)
      end

      config.activity, config.builder = Activity.FastTrack()
    end
  end
end



        # inherit: true
        # RECORD_OPTIONS = [:pass_fast, :fail_fast, :fast_track]

        # *If* {fast_track: true} (or :pass_fast or :fail_fast), record it using Normalizer::Inherit mechanics.
        # def record_options(ctx, flow_options, _, **)
        #   recorded_options =
        #     RECORD_OPTIONS.collect { |option| ctx.key?(option) ? [option, ctx[option]] : nil }
        #       .compact
        #       .to_h

        #   ctx = ctx.merge(
        #     Linear::Normalizer::Inherit.Record(recorded_options, type: :fast_track)
        #   )

        #   return ctx, flow_options
        # end

    #     def add_fail_fast_output(ctx, flow_options, _, outputs:, fail_fast: nil, **)
    #       return ctx, flow_options unless fail_fast

    #       ctx = ctx.merge(outputs: FAIL_FAST_OUTPUT.merge(outputs))

    #       return ctx, flow_options
    #     end

    #     def add_fast_track_outputs(ctx, flow_options, _, outputs:, fast_track: nil, **)
    #       return ctx, flow_options unless fast_track

    #       ctx = ctx.merge(outputs: FAIL_FAST_OUTPUT.merge(PASS_FAST_OUTPUT).merge(outputs))

    #       return ctx, flow_options
    #     end

    #     PASS_FAST_OUTPUT = {pass_fast: Activity.Output(Activity::FastTrack::PassFast, :pass_fast)}
    #     FAIL_FAST_OUTPUT = {fail_fast: Activity.Output(Activity::FastTrack::FailFast, :fail_fast)}

    #     def add_fast_track_tuples(ctx, flow_options, _, fast_track: nil, **)
    #       ctx = merge_connections_for(ctx, :fast_track, :pass_fast, :pass_fast)
    #       ctx = merge_connections_for(ctx, :fast_track, :fail_fast, :fail_fast)

    #       return ctx, flow_options
    #     end

    #     def pass_fast_option(ctx, flow_options, _, outputs:, **)
    #       ctx = merge_connections_for(ctx, :pass_fast, :success)

    #       ctx = merge_connections_for(ctx, :pass_fast, :pass_fast, :pass_fast) if outputs[:pass_fast]

    #       return ctx, flow_options
    #     end

    #     def pass_fast_option_for_pass(ctx, flow_options, _, **)
    #       ctx = merge_connections_for(ctx, :pass_fast, :failure)
    #       ctx = merge_connections_for(ctx, :pass_fast, :success)

    #       return ctx, flow_options
    #     end

    #     def fail_fast_option(ctx, flow_options, _, outputs:, **)
    #       ctx = merge_connections_for(ctx, :fail_fast, :failure)

    #       # DISCUSS: instead of checking outputs here, we could introduce something like Output(non_strict: true)
    #       ctx = merge_connections_for(ctx, :fail_fast, :fail_fast, :fail_fast) if outputs[:fail_fast]

    #       return ctx, flow_options
    #     end

    #     def fail_fast_option_for_fail(ctx, flow_options, _, **)
    #       ctx = merge_connections_for(ctx, :fail_fast, :failure)
    #       ctx = merge_connections_for(ctx, :fail_fast, :success)

    #       return ctx, flow_options
    #     end

    #     def merge_connections_for(ctx, option_name, semantic, magnetic_to = option_name, **)
    #       return ctx unless ctx[option_name]

    #       connector = {Linear::Normalizer::OutputTuples.Output(semantic) => Linear::Strategy.Track(magnetic_to)}

    #       connector.merge(ctx)
    #     end

    #     # Normalizer pipelines taking care of processing your DSL options.
    #     Normalizers = Linear::Normalizer::Normalizers.new(
    #       step: FastTrack::DSL.Normalizer(),
    #       fail: FastTrack::DSL::Fail.Normalizer(),
    #       pass: FastTrack::DSL::Pass.Normalizer(),
    #       terminus: Linear::Normalizer::Terminus.Normalizer(),
    #     )

    #     # Default options for build.
    #     def self.options_for_initialize(fail_fast_end: Activity::End.new(semantic: :fail_fast), pass_fast_end: Activity::End.new(semantic: :pass_fast), **options)
    #       options = Railway::DSL.options_for_initialize(**options)

    #       layout_instructions = options[:layout_instructions] + [
    #         [:terminus, task: fail_fast_end, magnetic_to: :fail_fast, id: "End.fail_fast", after: nil],
    #         [:terminus, task: pass_fast_end, magnetic_to: :pass_fast, id: "End.pass_fast", after: nil],
    #       ]

    #       normalizer_options = options[:normalizer_options].merge(fail_fast_end: fail_fast_end, pass_fast_end: pass_fast_end) # FIXME: do we need this?

    #       {
    #         layout_instructions: layout_instructions,
    #         normalizers: Normalizers,
    #         normalizer_options: normalizer_options
    #       }
    #     end

    #   end # DSL

    #   class << self
    #     private def fail(*args, &block)# FIXME: what about Railway?
    #       recompile_activity_for(:fail, *args, &block) # from Path::Strategy
    #     end
    #     alias left fail

    #     private def pass(*args, &block)
    #       recompile_activity_for(:pass, *args, &block) # from Path::Strategy
    #     end
    #   end

    #   compile_strategy!(DSL)
    # end # FastTrack

    # def self.FastTrack(**kws, &block)
    #   Activity::DSL::Linear::Strategy::DSL.Build(FastTrack, **kws, &block)
    # end
