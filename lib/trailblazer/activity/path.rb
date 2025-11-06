module Trailblazer
  class Activity
    # {Strategy} that helps building simple linear activities.
    class Path < DSL::Linear::Strategy
      # Functions that help creating a path-specific sequence.
      module DSL
        Linear = Activity::DSL::Linear
        # Always prepend all "add connectors" steps of all normalizers to normalize_output_tuples.
        # This assures that the order is
        #   [<default tuples>, <inherited tuples>, <user tuples>]
        PREPEND_TO = "output_tuples.normalize_output_tuples"

        module_function

        def Normalizer(prepend_to_default_outputs: {})
          path_output_steps = {
            "path.outputs" => method(:add_success_output)
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          dsl_normalizer = Linear::Normalizer.Normalizer(
            prepend_to_default_outputs: path_output_steps.merge(prepend_to_default_outputs)
          )

          Linear::Normalizer.prepend_to(
            dsl_normalizer,
            PREPEND_TO,
            {
              "path.step.add_success_connector" => method(:add_success_connector),
              "path.magnetic_to"                => method(:normalize_magnetic_to),
            }
          )
        end

        SUCCESS_OUTPUT = {success: Activity::Output(Activity::Right, :success)}

        def add_success_output(ctx, flow_options, _, **)
          ctx = ctx.merge(outputs: SUCCESS_OUTPUT)

          return ctx, flow_options
        end

        def add_success_connector(ctx, flow_options, _, track_name:, **)
          connectors = {Linear::Normalizer::OutputTuples.Output(:success) => Linear::Strategy.Track(track_name)}

          ctx = connectors.merge(ctx)

          return ctx, flow_options
        end

        def normalize_magnetic_to(ctx, flow_options, _, track_name:, **) # TODO: merge with Railway.merge_magnetic_to
          ctx = ctx.merge(magnetic_to: ctx.key?(:magnetic_to) ? ctx[:magnetic_to] : track_name) # FIXME: can we be magnetic_to {nil}?

          return ctx, flow_options
        end

        # This is slow and should be done only once at compile-time,
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step:     Normalizer(), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # pp Normalizers

        # DISCUSS: following methods are not part of Normalizer

        # Default options for build.
        def self.options_for_build(track_name: :success, end_task: Trailblazer::Activity::End.new(semantic: :success), end_id: "End.success")
          start = Trailblazer::Activity::Start.new(semantic: :default)

          {
            layout_instructions: [
              [:step, id: "Start.default", task: start, magnetic_to: nil, after: nil, outputs: {success: Activity.Output(Trailblazer::Activity::Right, :success)}], # DISCUSS: technically, we shouldn't have to define only one output here, but it's easier for Railway and FastTrack.
              [:terminus, id: end_id, task: end_task, magnetic_to: track_name, after: nil],
            ],

            normalizers: Normalizers, # see above.

            # normalizer_options?
            normalizer_options: {
              track_name: track_name,

  # FIXME: needed in #wrap_task_with_step_interface
              step_interface_builder: Trailblazer::Activity::DSL::Linear::Normalizer.method(:build_circuit_step_for_filter), # DISCUSS: hm, do we want this here in Path, for example?
  # FIXME: needed in #normalize_sequence_insert
              end_id: end_id,
            }
          }
        end
      end # DSL

      compile_strategy!(Path::DSL) # sets :normalizer, normalizer_options, sequence and activity on @state.
    end # Path

    def self.Path(**options, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(Path, options, &block)
    end
  end
end
