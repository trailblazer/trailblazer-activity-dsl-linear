module Trailblazer
  class Activity
    # {Strategy} that helps building simple linear activities.
    class Path
      # Functions that help creating a path-specific sequence.
      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def normalizer
          prepend_step_options(
            initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")
          )
        end

        def start_sequence(track_name:)
          start_default = Activity::Start.new(semantic: :default)
          start_event   = Linear::Sequence.create_row(task: start_default, id: "Start.default", magnetic_to: nil, wirings: [Linear::Search::Forward(unary_outputs[:success], track_name)])
          sequence      = Linear::Sequence[start_event]
        end

        # DISCUSS: still not sure this should sit here.
        # Pseudo-DSL that prepends {steps} to {sequence}.
        def prepend_to_path(sequence, steps, insertion_method=Linear::Insert.method(:Prepend), insert_id="End.success")
          new_rows = steps.collect do |id, task|
            Linear::Sequence.create_row(
              task:         task,
              magnetic_to:  :success,
              wirings:      [Linear::Search::Forward(unary_outputs[:success], :success)],
              id:           id,
            )
          end

          insertion_method.(sequence, new_rows, insert_id)
        end

        def unary_outputs
          {success: Activity::Output(Activity::Right, :success)}
        end

        def unary_connections(track_name: :success)
          {success: [Linear::Search.method(:Forward), track_name]}
        end

        def merge_path_outputs((ctx, flow_options), *)
          ctx = {outputs: unary_outputs}.merge(ctx)

          return Right, [ctx, flow_options]
        end

        def merge_path_connections((ctx, flow_options), *)
          raise unless track_name = ctx[:track_name]# TODO: make track_name required kw.
          ctx = {connections: unary_connections(track_name: track_name)}.merge(ctx)

          return Right, [ctx, flow_options]
        end

        # Processes {:before,:after,:replace,:delete} options and
        # defaults to {before: "End.success"} which, yeah.
        def normalize_sequence_insert((ctx, flow_options), *)
          insertion = ctx.keys & sequence_insert_options.keys
          insertion = insertion[0]   || :before
          raise if ctx[:end_id].nil? # FIXME
          target    = ctx[insertion] || ctx[:end_id]

          insertion_method = sequence_insert_options[insertion]

          ctx = ctx.merge(sequence_insert: [Linear::Insert.method(insertion_method), target])

          return Right, [ctx, flow_options]
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

        def raise_on_duplicate_id((ctx, flow_options), *)
          id, sequence, insert = ctx[:id], ctx[:sequence], ctx[:sequence_insert][0] # DISCUSS: should we use Replace here or rather the option(s)?

          if insert != Linear::Insert.method(:Replace)
            raise "ID #{id} is already taken. Please specify an `:id`." if sequence.find { |row| row[3][:id] == id }
          end

          return Right, [ctx, flow_options]
        end

        def normalize_magnetic_to((ctx, flow_options), *) # TODO: merge with Railway.merge_magnetic_to
          raise unless track_name = ctx[:track_name]# TODO: make track_name required kw.

          ctx = {magnetic_to: track_name}.merge(ctx)

          return Right, [ctx, flow_options]
        end

        # Return {Path::Normalizer} sequence.
        def prepend_step_options(sequence)
          prepend_to_path(
            sequence,

            "path.outputs"          => method(:merge_path_outputs),
            "path.connections"      => method(:merge_path_connections),
            "path.sequence_insert"  => method(:normalize_sequence_insert),
            "path.raise_on_duplicate_id"  => method(:raise_on_duplicate_id),
            "path.magnetic_to"      => method(:normalize_magnetic_to),
            "path.wirings"          => Linear::Normalizer.method(:compile_wirings),
          )
        end

        # Returns an initial two-step sequence with {Start.default > End.success}.
        def initial_sequence(track_name:, end_task:, end_id:)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
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

        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Path::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        )

        # pp Normalizers

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
          def step(*args)
            seq = Linear::Strategy.task_for!(self, :step, *args) # mutate @state
          end
        end

      end # DSL

      include DSL::Linear::Helper
      extend DSL::Linear::Strategy

      initialize!(Path::DSL::State.new(**DSL.OptionsForState()))
    end # Path

    def self.Path(options)
      Class.new(Path) do
        initialize!(Path::DSL::State.new(**Path::DSL.OptionsForState(**options)))
      end
    end
  end
end

