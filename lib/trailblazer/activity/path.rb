module Trailblazer
  class Activity < Module
    def self.Path(options={})
      Activity::Path.new(Path, options)
    end

    # Implementation module that can be passed to `Activity[]`.
    class Path < Activity
      module DSL
        # move out defaulting ( {|| :success} ) and move it into one central place. easier to debug/understand where values come from.
        Linear = Activity::DSL::Linear # FIXME

        module_function

        def normalizer
          step_options_for_path(Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success))
        end

        # FIXME: where does Start come from?
        Right = Trailblazer::Activity::Right
        def start_sequence(track_name:)
          start_default = Trailblazer::Activity::Start.new(semantic: :default)
          start_event   = Linear::DSL.create_row(task: start_default, id: "Start.default", magnetic_to: nil, outputs: unary_outputs, connections: unary_connections(track_name: track_name))
          sequence      = Linear::Sequence[start_event]
        end

        # DISCUSS: still not sure this should sit here.
        # Pseudo-DSL that prepends {steps} to {sequence}.
        def prepend_to_path(sequence, steps, **options)
          steps.each do |id, task|
            sequence = Linear::DSL.insert_task(sequence, task: task,
              magnetic_to: :success, id: id, outputs: unary_outputs, connections: unary_connections,
              sequence_insert: [Linear::Insert.method(:Prepend), "End.success"], **options)
          end

          sequence
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
          target    = ctx[insertion] || "End.success"

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

        def normalize_magnetic_to((ctx, flow_options), *) # TODO: merge with Railway.merge_magnetic_to
          raise unless track_name = ctx[:track_name]# TODO: make track_name required kw.

          ctx = ctx.merge(magnetic_to: track_name)

          return Right, [ctx, flow_options]
        end

        def step_options_for_path(sequence)
          prepend_to_path(
            sequence,

            "path.outputs"          => method(:merge_path_outputs),
            "path.connections"      => method(:merge_path_connections),
            "path.sequence_insert"  => method(:normalize_sequence_insert),
            "path.magnetic_to"      => method(:normalize_magnetic_to),
          )
        end

        # Returns an initial two-step sequence with {Start.default > End.success}.
        def initial_sequence(track_name:)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = start_sequence(track_name: track_name)
          sequence = append_end(sequence, task: Activity::End.new(semantic: :success), magnetic_to: track_name, id: "End.success", append_to: "Start.default")
        end

        def append_end(sequence, **options)
          sequence = Linear::DSL.insert_task(sequence, **append_end_options(options))
        end

        def append_end_options(task:, magnetic_to:, id:, append_to: "End.success")
          end_args = {sequence_insert: [Linear::Insert.method(:Append), append_to], stop_event: true}

          {
            task:         task,
            magnetic_to:  magnetic_to,
            id:           id,
            outputs:      {magnetic_to => Activity::Output.new(task, task.to_h[:semantic])}, # DISCUSS: do we really want to transport the semantic "in" the object?
            connections:  {magnetic_to => [Linear::Search.method(:Noop)]},
            **end_args
           }
        end

        class State # TODO : MERGE WITH RAILWAY::State
          def initialize(normalizers:, initial_sequence:, framework_options:)
            @normalizer  = normalizers # compiled normalizers.
            @sequence    = initial_sequence

            # remembers how to call normalizers (e.g. track_color), TaskBuilder
            # remembers sequence

            @framework_options = framework_options
          end

          def step(task, options={}, &block)
            options = @normalizer.(:step, framework_options: @framework_options, options: task, user_options: options)

            options, locals = Linear.normalize(options, [:adds]) # DISCUSS: Part of the DSL API.

            [options, *locals[:adds]].each do |insertion|
              @sequence = Linear::DSL.insert_task(@sequence, **insertion)
            end

            @sequence
          end
        end # State
        Linear = Activity::DSL::Linear
        # This is slow and should be done only once at compile-time,
        # DISCUSS: maybe make this a function?
        # These are the normalizers for an {Activity}, to be injected into a State.
        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Path::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        )


        def self.OptionsForState(normalizers: Normalizers, track_name: :success, **options)
          initial_sequence = Path::DSL.initial_sequence(track_name: track_name)

          {
            normalizers: normalizers,
            initial_sequence: initial_sequence,
            framework_options: {
              track_name: track_name,
              step_interface_builder: Trailblazer::Activity::TaskBuilder.method(:Binary),
              adds: [], # FIXME: EH.
              **options
            }
          }
        end

      end # DSL
    end # Path
  end
end

