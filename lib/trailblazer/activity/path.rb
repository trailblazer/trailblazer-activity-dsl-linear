module Trailblazer
  class Activity
    # {Strategy} that helps building simple linear activities.
    class Path < DSL::Linear::Strategy
      # Functions that help creating a path-specific sequence.
      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer
          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          dsl_normalizer = Linear::Normalizer.Normalizer()

          Linear::Normalizer.prepend_to(
            dsl_normalizer,
            # "activity.wirings",
            "activity.normalize_outputs_from_dsl",
            {
              "path.outputs"                => Linear::Normalizer.Task(method(:merge_path_outputs)),
              "path.connections"            => Linear::Normalizer.Task(method(:merge_path_connections)),
              "path.magnetic_to"            => Linear::Normalizer.Task(method(:normalize_magnetic_to)),
            }
          )
        end

        def unary_outputs
          {success: Activity::Output(Activity::Right, :success)}
        end

        def unary_connections(track_name: :success)
          {success: [Linear::Sequence::Search.method(:Forward), track_name]}
        end

        def merge_path_outputs(ctx, outputs: nil, **)
          ctx[:outputs] = outputs || unary_outputs
        end

        def merge_path_connections(ctx, track_name:, connections: nil, **)
          ctx[:connections] = connections || unary_connections(track_name: track_name)
        end

        def normalize_magnetic_to(ctx, track_name:, **) # TODO: merge with Railway.merge_magnetic_to
          ctx[:magnetic_to] = ctx.key?(:magnetic_to) ? ctx[:magnetic_to] : track_name # FIXME: can we be magnetic_to {nil}?
        end

        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::Normalizer::Normalizers.new(
          step:     Normalizer(), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # pp Normalizers

        # DISCUSS: following methods are not part of Normalizer

        def append_terminus(sequence, task, normalizers:, **options)
          _sequence = Linear::Sequence::Builder.update_sequence_for(:terminus, task, options, normalizers: normalizers, sequence: sequence, normalizer_options: {})
        end

        # @private
        def start_sequence(track_name:)
          Linear::Strategy::DSL.start_sequence(wirings: [Linear::Sequence::Search::Forward(unary_outputs[:success], track_name)])
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

=begin
class Operation
  def self.subclassed(track_name:) # FIXME: it should be run in SubOperation context.
    # initialize code here
  end

end

SubOperation = Class.new(Operation, track_name: :green)
=end
