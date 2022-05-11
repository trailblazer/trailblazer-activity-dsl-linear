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
          _sequence = State.update_sequence_for(:terminus, task, options, normalizers: normalizers, normalizer_options: {}, sequence: sequence)
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

        def OptionsForState(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success", **options)
          initial_sequence = initial_sequence(track_name: track_name, end_task: end_task, end_id: end_id) # DISCUSS: the standard initial_seq could be cached.

          {
            normalizers:      normalizers,
            initial_sequence: initial_sequence,

            track_name:             track_name,
            end_id:                 end_id,
            step_interface_builder: Activity::TaskBuilder.method(:Binary), # DISCUSS: this is currently the only option we want to pass on in Path() ?
            adds:                   [],
            **options
          }
        end

        # Implements the actual API ({#step} and friends).
        # This can be used later to create faster DSLs where the activity is compiled only once, a la
        #   Path() do  ... end
        class State < Linear::State
          def step(*args, &block)
            update_sequence_for!(:step, *args, &block) # mutate @state
          end

          def terminus(*args)
            update_sequence_for!(:terminus, *args)
          end

          include Linear::Helper # Subprocess(), Output(), ...
          include Linear::Helper::Constants # FIXME: test me! # {Contract::Build()} and friends.

          def Path(**options, &block)
            options = options.merge(block: block) if block_given?

            # DISCUSS: we're copying normalizer_options here, and not later in the normalizer!
            Linear::PathBranch.new(@state.get(:normalizer_options).merge(options)) # picked up by normalizer.
          end
        end # State
      end # DSL

      recompile_for_state!(Path::DSL::State, DSL.OptionsForState())
    end # Path

    def self.Path(**options)
      Class.new(Path) do
        recompile_for_state!(Path::DSL::State, **Path::DSL.OptionsForState(**options))
        # state, _ = .build(**Path::DSL.OptionsForState(**options))
        # initialize!(state)
      end
    end
  end
end

