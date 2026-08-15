module Trailblazer
  class Activity
    def self.Railway(track_name: :success, normalizers: Railway::NORMALIZERS, &block)
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: :failure,
            outputs: {},
          },
          left: {
            magnetic_to: :failure,
            track_name: :failure,
            failure_track_name: :failure,
            outputs: {}
          },
          pass: {
            magnetic_to: track_name,
            track_name: track_name,
            failure_track_name: track_name,
            outputs: {}
          }
        }
      )

      options_for_terminus = { # TODO: get from Path.
        task:        success_terminus = Trailblazer::Activity::Terminus::Success.new(semantic: track_name),
        wirings:     Path.wirings_for_terminus(signal: success_terminus, semantic: track_name),
        id:          DSL.id_for_terminus(semantic: track_name),
        magnetic_to: track_name
      }

      options_for_failure_terminus = {
        task:        failure_terminus = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure),
        wirings:     Path.wirings_for_terminus(signal: failure_terminus, semantic: :failure),
        id:          DSL.id_for_terminus(semantic: :failure),
        magnetic_to: :failure
      }

      activity, _ = builder.() do
        step **options_for_terminus
        step **options_for_failure_terminus, adds_insertion_args: [:after]
      end

      return activity, builder
    end

    class Railway < DSL::Topology
      extend DSL::Left
      extend DSL::Pass

      module Normalizer
        # normalizer_for_fail = Circuit::Builder.Circuit(
        #   [:normalize_magnetic_to, method(:normalize_magnetic_to)],
        #   [:add_success_connector, AddConnection.new(:success, Right)],
        #   [:add_failure_connector, AddConnection.new(:failure, Left)],
        # )

        # Node = Circuit::Node[:bla_FIXME, circuit, Circuit::Processor]
      end

      NORMALIZERS = {
        step: Path::Normalizer::Step,
        left: Path::Normalizer::Step,
        pass: Path::Normalizer::Step
      }.freeze


      config.activity, config.builder = Activity.Railway() # Activity::Railway is just a simple, pre-configured frontend.



    #     module Pass
    #       module_function

    #       def Normalizer(**options)
    #         Linear::Normalizer.replace(
    #           DSL.Normalizer(**options), # grab Railway::DSL::Normalizer.
    #           "railway.step.add_failure_connector",
    #           ["railway.pass.failure_to_success", Pass.method(:connect_failure_to_success)]
    #         )
    #       end

    #       FAILURE_TO_SUCCESS_CONNECTOR = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:success)}

    #       def connect_failure_to_success(ctx, flow_options, _, **options)
    #         Railway::DSL.add_failure_connector(ctx, flow_options, _, **options, failure_connector: FAILURE_TO_SUCCESS_CONNECTOR)
    #       end
    #     end

    #     FAILURE_OUTPUT    = {failure: Activity::Output(Activity::Left, :failure)}
    #     FAILURE_CONNECTOR = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:failure)}
    #     PASS_CONNECTOR    = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:success)}
    #     FAIL_CONNECTOR    = {Linear::Normalizer::OutputTuples.Output(:success) => Linear::Strategy.Track(:failure)}

    #     # Add {:failure} output to {:outputs}.
    #     # This is only called for non-Subprocess steps.
    #     def add_failure_output(ctx, flow_options, _, outputs:, **)
    #       ctx = ctx.merge(
    #         outputs: FAILURE_OUTPUT.merge(outputs)
    #       )

    #       return ctx, flow_options
    #     end

    #     def add_failure_connector(ctx, flow_options, _, outputs:, failure_connector: FAILURE_CONNECTOR, **)
    #       return ctx, flow_options unless outputs[:failure] # do not add the default failure connection when we don't have
    #                                       # a corresponding output.

    #       ctx = failure_connector.merge(ctx)

    #       return ctx, flow_options
    #     end

    #     Normalizers = Linear::Normalizer::Normalizers.new(
    #       step:  Railway::DSL.Normalizer(),
    #       fail:  Railway::DSL::Fail.Normalizer(),
    #       pass:  Railway::DSL::Pass.Normalizer(),
    #       terminus: Linear::Normalizer::Terminus.Normalizer(),
    #     )

    #     # Default options for build.
    #     def self.options_for_initialize(failure_end: Activity::End.new(semantic: :failure), **options)
    #       options = Path::DSL.options_for_initialize(**options)

    #       layout_instructions = options[:layout_instructions] +
    #         [[:terminus, task: failure_end, magnetic_to: :failure, id: "End.failure", after: nil]]

    #       normalizer_options = options[:normalizer_options].merge(failure_end: failure_end) # FIXME: do we need this?

    #       {
    #         layout_instructions: layout_instructions,
    #         normalizers: Normalizers,
    #         normalizer_options: normalizer_options
    #       }
    #     end
    #   end # DSL

    #   class << self
    #     def fail(*args, &block)
    #       recompile_activity_for(:fail, *args, &block)
    #     end
    #     alias left fail

    #     def pass(*args, &block)
    #       recompile_activity_for(:pass, *args, &block)
    #     end
    #   end

    #   compile_strategy!(DSL)
    #   # pp @state.get(:sequence)
    # end # Railway

    # def self.Railway(**kws, &block)
    #   Activity::DSL::Linear::Strategy::DSL.Build(Railway, **kws, &block)
    end
  end
end
