module Trailblazer
  class Activity
    def self.FastTrack(track_name: :success, normalizers: FastTrack::NORMALIZERS, &block)
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: Railway.default_options(track_name: track_name)
      )

      fast_track_termini = {
        success: Terminus::Success,
        failure: Terminus::Failure,
        pass_fast: FastTrack::Terminus::PassFast,
        fail_fast: FastTrack::Terminus::FailFast
      }

      activity, _ = builder.() do
        # add the four termini to the FastTrack topology by simply using #step.
        fast_track_termini.each do |semantic, terminus_class|
          step **DSL.options_for_terminus_step(semantic: semantic, terminus_class: terminus_class)
        end
      end

      return activity, builder
    end

    class FastTrack < DSL::Topology
      extend DSL::Left
      extend DSL::Pass
      extend DSL::Feature::Terminus

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

        def add_fast_track_tuples(ctx, flow_options, _, fast_track: nil, **)
          return ctx, flow_options unless fast_track

          return ctx.merge(
            Helper.Output(:pass_fast, signal: FastTrack::Signal::PassFast) => Helper.Track(:pass_fast),
            Helper.Output(:fail_fast, signal: FastTrack::Signal::FailFast) => Helper.Track(:fail_fast)
          ), flow_options
        end

        circuit = Circuit::Builder.Circuit(
          [:add_pass_fast_tuple, method(:add_pass_fast_tuple)],
          [:add_fail_fast_tuple, method(:add_fail_fast_tuple)],
          [:add_fast_track_tuples, method(:add_fast_track_tuples)],
        )

        Node = Circuit::Node[:bla_FIXME, circuit, Circuit::Processor]

        Step = Circuit::Adds.(
          Path::Normalizer::Step,
          [
            :normalize_fast_track_options, Node,
            :before, :normalize_wirings
          ]
        )

        # module Pass
          module_function
          def add_pass_fast_tuple_for_failure(ctx, flow_options, _, pass_fast: nil, **)
            return ctx, flow_options unless pass_fast # FIXME: sort this out in a higher node.

            return ctx.merge(Helper.Output(:failure) => Helper.Track(:pass_fast)), flow_options
          end

          def add_fail_fast_tuple_for_success(ctx, flow_options, _, fail_fast: nil, **)
            return ctx, flow_options unless fail_fast # FIXME: sort this out in a higher node.

            return ctx.merge(Helper.Output(:success) => Helper.Track(:fail_fast)), flow_options
          end
        # end

        # DISCUSS: this could be done much cooler by adding this step to the above circuit, etc.
        Pass = Circuit::Adds.(
          Step,
          [
            :add_pass_fast_tuple_for_failure, Circuit::Node[:bla_FIXME, method(:add_pass_fast_tuple_for_failure), Circuit::Task::Adapter::LibInterface],
            :after, :normalize_fast_track_options
          ]
        )

        Fail = Circuit::Adds.(
          Step,
          [
            :add_fail_fast_tuple_for_success, Circuit::Node[:bla_FIXME, method(:add_fail_fast_tuple_for_success), Circuit::Task::Adapter::LibInterface],
            :after, :normalize_fast_track_options
          ]
        )
      end # Normalizer


      NORMALIZERS = {
        step: FastTrack::Normalizer::Step,
        left: FastTrack::Normalizer::Fail,
        pass: FastTrack::Normalizer::Pass
      }.freeze

      module Terminus
        PassFast = Class.new(Activity::Terminus::Success)
        FailFast = Class.new(Activity::Terminus::Failure)
      end

      module Signal
        PassFast = Class.new(Activity::Signal)
        FailFast = Class.new(Activity::Signal)
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



