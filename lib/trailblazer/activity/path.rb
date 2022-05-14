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

          TaskWrap::Pipeline.prepend(
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
          {success: [Linear::Search.method(:Forward), track_name]}
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
        Normalizers = Linear::State::Normalizer.new(
          step:     Normalizer(), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # pp Normalizers

        # DISCUSS: following methods are not part of Normalizer

        def append_terminus(sequence, task, normalizers:, **options)
          _sequence = Linear::Sequencer.update_sequence_for(:terminus, task, options, normalizers: normalizers, normalizer_options: {}, sequence: sequence)
        end

        # @private
        def start_sequence(track_name:)
          Linear::Strategy::DSL.start_sequence(wirings: [Linear::Search::Forward(unary_outputs[:success], track_name)])
        end

        # Returns an initial two-step sequence with {Start.default > End.success}.
        def initial_sequence(track_name:, end_task:, end_id:)
          sequence = start_sequence(track_name: track_name)
          sequence = append_terminus(sequence, end_task, id: end_id, magnetic_to: track_name, normalizers: Normalizers, append_to: "Start.default")
        end

        def OptionsForSequencer(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success", **options)
          initial_sequence = initial_sequence(track_name: track_name, end_task: end_task, end_id: end_id)

          {
            normalizers:        normalizers,
            sequence:           initial_sequence,
            normalizer_options: {
              track_name:             track_name,
              end_id:                 end_id,
              step_interface_builder: Activity::TaskBuilder.method(:Binary), # DISCUSS: this is currently the only option we want to pass on in Path() ?
              adds:                   [], # DISCUSS: needed?
              **options
            }
          }
        end
      end # DSL

      compile_strategy!(DSL)
    end # Path

    def self.Path(**options, &block)
      Class.new(Path) do
        compile_strategy!(Path::DSL, **options)

        instance_exec(&block) if block_given?
      end
    end
  end
end

