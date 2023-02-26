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

        def Normalizer(prepend_to_default_outputs: [])
          path_output_steps = {
            "path.outputs" => Linear::Normalizer.Task(method(:add_success_output))
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          dsl_normalizer = Linear::Normalizer.Normalizer(
            prepend_to_default_outputs: [*prepend_to_default_outputs, path_output_steps]
          )

          Linear::Normalizer.prepend_to(
            dsl_normalizer,
            PREPEND_TO,
            {
              "path.step.add_success_connector" => Linear::Normalizer.Task(method(:add_success_connector)),
              "path.magnetic_to"                => Linear::Normalizer.Task(method(:normalize_magnetic_to)),
            }
          )
        end

        SUCCESS_OUTPUT = {success: Activity::Output(Activity::Right, :success)}

        def add_success_output(ctx, **)
          ctx[:outputs] = SUCCESS_OUTPUT
        end

        def add_success_connector(ctx, track_name:, non_symbol_options:, **)
          connectors = {Linear::Normalizer::OutputTuples.Output(:success) => Linear::Strategy.Track(track_name)}

          ctx[:non_symbol_options] = connectors.merge(non_symbol_options)
        end

        def normalize_magnetic_to(ctx, track_name:, **) # TODO: merge with Railway.merge_magnetic_to
          ctx[:magnetic_to] = ctx.key?(:magnetic_to) ? ctx[:magnetic_to] : track_name # FIXME: can we be magnetic_to {nil}?
        end

        # This is slow and should be done only once at compile-time,
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step:     Normalizer(), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # pp Normalizers

        # DISCUSS: following methods are not part of Normalizer

        # @private
        def start_sequence(track_name:)
          Linear::Strategy::DSL.start_sequence(wirings: [Linear::Sequence::Search::Forward(SUCCESS_OUTPUT[:success], track_name)])
        end

        def options_for_sequence_build(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success", **)
          initial_sequence = start_sequence(track_name: track_name)

          termini = [
            [end_task, id: end_id, magnetic_to: track_name, append_to: "Start.default"]
          ]

          options = {
            sequence:   initial_sequence,
            track_name: track_name,
            end_id:     end_id,           # needed in Normalizer.normalize_sequence_insert.
          }

          return options, termini
        end
      end # DSL

      compile_strategy!(Path::DSL, normalizers: DSL::Normalizers) # sets :normalizer, normalizer_options, sequence and activity
    end # Path

    def self.Path(**options, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(Path, **options, &block)
    end
  end
end
