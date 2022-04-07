module Trailblazer
  class Activity
    # {Strategy} that helps building simple linear activities.
    class Path
      # Functions that help creating a path-specific sequence.
      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def normalizer
          TaskWrap::Pipeline.new(normalizer_steps.to_a)
        end

        # Return {Path::Normalizer} sequence.
        private def normalizer_steps
          {
            "path.outputs"                => Linear::Normalizer.Task(method(:merge_path_outputs)),
            "path.connections"            => Linear::Normalizer.Task(method(:merge_path_connections)),
            "path.sequence_insert"        => Linear::Normalizer.Task(method(:normalize_sequence_insert)),
            "path.normalize_duplications" => Linear::Normalizer.Task(method(:normalize_duplications)),
            "path.magnetic_to"            => Linear::Normalizer.Task(method(:normalize_magnetic_to)),
            "path.wirings"                => Linear::Normalizer.Task(Linear::Normalizer.method(:compile_wirings)),
          }
        end

        def start_sequence(track_name:)
          start_default = Activity::Start.new(semantic: :default)
          start_event   = Linear::Sequence.create_row(task: start_default, id: "Start.default", magnetic_to: nil, wirings: [Linear::Search::Forward(unary_outputs[:success], track_name)])
          _sequence     = Linear::Sequence[start_event]
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

        # Processes {:before,:after,:replace,:delete} options and
        # defaults to {before: "End.success"} which, yeah.
        def normalize_sequence_insert(ctx, end_id:, **)
          insertion = ctx.keys & sequence_insert_options.keys
          insertion = insertion[0]   || :before
          target    = ctx[insertion] || end_id

          insertion_method = sequence_insert_options[insertion]

          ctx[:sequence_insert] = [Linear::Insert.method(insertion_method), target]
        end

        # @private
        def sequence_insert_options
          {
            :before  => :Prepend,
            :after   => :Append,
            :replace => :Replace,
            :delete  => :Delete,
          }
        end

        def normalize_duplications(ctx, replace: false, **)
          return if replace

          raise_on_duplicate_id(ctx, **ctx)
          clone_duplicate_activity(ctx, **ctx) # DISCUSS: mutates {ctx}.
        end

        def raise_on_duplicate_id(ctx, id:, sequence:, **)
          raise "ID #{id} is already taken. Please specify an `:id`." if sequence.find { |row| row[3][:id] == id }
        end

        def clone_duplicate_activity(ctx, task:, sequence:, **)
          return unless task.is_a?(Class)

          ctx[:task] = task.clone if sequence.find { |row| row[1] == task }
        end

        def normalize_magnetic_to(ctx, track_name:, **) # TODO: merge with Railway.merge_magnetic_to
          ctx[:magnetic_to] = ctx.key?(:magnetic_to) ? ctx[:magnetic_to] : track_name # FIXME: can we be magnetic_to {nil}?
        end

        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer(Path::DSL.normalizer), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        )

        # pp Normalizers

      # DISCUSS: following methods are not part of Normalizer
        # Returns an initial two-step sequence with {Start.default > End.success}.
        def initial_sequence(track_name:, end_task:, end_id:)
          # DISCUSS: this could be an Activity itself but maybe a bit too much for now.
          sequence = start_sequence(track_name: track_name)
          sequence = append_end(sequence, task: end_task, magnetic_to: track_name, id: end_id, append_to: "Start.default")
        end

        def append_end(sequence, **options)
          sequence = Linear::DSL.insert_task(sequence, **append_end_options(**options))
        end

        def append_end_options(task:, magnetic_to:, id:, append_to: "End.success")
          end_args = {sequence_insert: [Linear::Insert.method(:Append), append_to], stop_event: true}

          {
            task:         task,
            magnetic_to:  magnetic_to,
            id:           id,
            wirings:      [
              Linear::Search::Noop(
                Activity::Output.new(task, task.to_h[:semantic]), # DISCUSS: do we really want to transport the semantic "in" the object?
                # magnetic_to
              )],
            # outputs:      {magnetic_to => },
            # connections:  {magnetic_to => [Linear::Search.method(:Noop)]},
            **end_args
           }
        end


        def self.OptionsForState(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success", **options)
          initial_sequence = Path::DSL.initial_sequence(track_name: track_name, end_task: end_task, end_id: end_id) # DISCUSS: the standard initial_seq could be cached.

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
            if args[1].is_a?(Hash)
              args[1][:block] = block # FIXME: this is all prototyping bullshit of course.
            end

            update_sequence_for!(:step, *args) # mutate @state
          end

          # TODO: how to implement "macro forwarding" across all strategies and states? also, keep in mind `Contract::Validate()` etc
          # FIXME: redundancy
          def Output(*args); Linear.Output(*args) end
          def Id(*args); Linear.Id(*args) end
          def Subprocess(*args, **kws); Linear.Subprocess(*args, **kws) end
          def End(*args, **kws); Linear.End(*args, **kws) end
          def Path(**options, &block)
            options = options.merge(block: block) if block_given?

            # DISCUSS: we're copying normalizer_options here, and not later in the normalizer!
            Linear::Helper::PathBranch.new(@state.get("dsl/normalizer_options").merge(options)) # picked up by normalizer.
          end
        end # State

      end # DSL

      include DSL::Linear::Helper
      extend DSL::Linear::Strategy

      initialize!(Path::DSL::State.build(**DSL.OptionsForState()))
    end # Path

    def self.Path(**options)
      Class.new(Path) do
        initialize!(Path::DSL::State.build(**Path::DSL.OptionsForState(**options)))
      end
    end
  end
end

