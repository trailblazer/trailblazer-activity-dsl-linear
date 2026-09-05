module Trailblazer
  class Activity
    def self.FastTrack(normalizers: FastTrack.config.builder.normalizers, **options, &block)
      Path(normalizers: normalizers, **options, &block)
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

        def add_fast_track_tuples(ctx, flow_options, _, fast_track: nil, outputs:, **)
          return ctx, flow_options unless fast_track

          # Merge existing :outputs over our "suggestion", so {Subprocess et al} overrides us.
          outputs = {
            pass_fast: Output.new(FastTrack::Signal::PassFast, :pass_fast),
            fail_fast: Output.new(FastTrack::Signal::FailFast, :fail_fast),
          }.merge(outputs)

          return ctx.merge(
            outputs: outputs,
            Helper.Output(:pass_fast) => Helper.Track(:pass_fast),
            Helper.Output(:fail_fast) => Helper.Track(:fail_fast)
          ), flow_options
        end

        circuit = Circuit::Builder.Circuit(
          [:add_pass_fast_tuple, method(:add_pass_fast_tuple)],
          [:add_fail_fast_tuple, method(:add_fail_fast_tuple)],
          [:add_fast_track_tuples, method(:add_fast_track_tuples)],
        )

        Node = Circuit::Node[circuit, Circuit::Processor]

        Step = Circuit::Adds.(
          Path.config.builder.normalizers[:step], # DISCUSS: or Railway?
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
            :add_pass_fast_tuple_for_failure, Circuit::Node[method(:add_pass_fast_tuple_for_failure), Circuit::Task::Adapter::LibInterface],
            :after, :normalize_fast_track_options
          ]
        )

        Fail = Circuit::Adds.(
          Step,
          [
            :add_fail_fast_tuple_for_success, Circuit::Node[method(:add_fail_fast_tuple_for_success), Circuit::Task::Adapter::LibInterface],
            :after, :normalize_fast_track_options
          ]
        )
      end # Normalizer

      module Terminus
        PassFast = Class.new(Activity::Terminus::Success)
        FailFast = Class.new(Activity::Terminus::Failure)
      end

      module Signal
        PassFast = Class.new(Activity::Signal)
        FailFast = Class.new(Activity::Signal)
      end

      normalizers = {
        step: FastTrack::Normalizer::Step,
        left: FastTrack::Normalizer::Fail,
        pass: FastTrack::Normalizer::Pass
      }

      # By cloning Railway's builder, we "inherit" the imported helpers.
      fast_track_builder = Railway.config.builder.clone( # we inherit everything (set up sequence, helpers, normalizers)
        defaults: {}
      )
      fast_track_builder.normalizers = fast_track_builder.normalizers.merge(normalizers) # DISCUSS: not entirely sure this must be covered by #clone?

      config.activity, config.builder = Activity.Path(builder: fast_track_builder) do
        step **DSL.options_for_terminus_step(semantic: :pass_fast, terminus_class: FastTrack::Terminus::PassFast)
        step **DSL.options_for_terminus_step(semantic: :fail_fast, terminus_class: FastTrack::Terminus::FailFast)
      end

      extend Path.config.helper_forwarder # forward Output() and friends to {builder}.
    end
  end
end


