module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    def self.Railway(options={})
      Railway.new(Railway, options)
    end

    class Railway < Activity
      def self.config
        Path.config.merge(
          builder_class:   Magnetic::Builder::Railway,
          default_outputs: Magnetic::Builder::Path.default_outputs,
          extend:          [
            DSL::Linear.def_dsl(:step, Magnetic::Builder::Railway, :StepPolarizations),
            DSL::Linear.def_dsl(:fail, Magnetic::Builder::Railway, :FailPolarizations),
            DSL::Linear.def_dsl(:pass, Magnetic::Builder::Railway, :PassPolarizations),
            DSL::Linear.def_dsl(:_end, Magnetic::Builder::Path,    :EndEventPolarizations), # TODO: TEST ME
          ],
        )
      end

      module DSL
        Linear = Activity::DSL::Linear # FIXME

        module_function

        def normalizer
          step_options(Trailblazer::Activity::Path::DSL.normalizer)
        end

        # Change some parts of the "normal" {normalizer} pipeline.
        # TODO: make this easier, even at this step.

        def normalizer_for_fail
          sequence = normalizer

          id = "railway.magnetic_to.fail"
          task = Fail.method(:merge_magnetic_to)

          sequence = Linear::DSL.insert_task(sequence, task: task,
                magnetic_to: :success, id: id, outputs: Path::DSL.unary_outputs, connections: Path::DSL.unary_connections,
                sequence_insert: [Linear::Insert.method(:Prepend), "End.success"])

          id = "railway.connections.fail.success_to_failure"
          task = Fail.method(:connect_success_to_failure)

          sequence = Linear::DSL.insert_task(sequence, task: task,
                magnetic_to: :success, id: id, outputs: Path::DSL.unary_outputs, connections: Path::DSL.unary_connections,
                sequence_insert: [Linear::Insert.method(:Replace), "path.connections"])
        end

        module Fail
          module_function

          def merge_magnetic_to((ctx, flow_options), *)
            ctx = ctx.merge(magnetic_to: :failure)

            return Right, [ctx, flow_options]
          end

          def connect_success_to_failure((ctx, flow_options), *)
            ctx = {connections: {success: [Linear::Search.method(:Forward), :failure]}}.merge(ctx)

            return Right, [ctx, flow_options]
          end
        end


        def step_options(sequence)
          Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            "railway.outputs"     => method(:normalize_path_outputs),
            "railway.connections" => method(:normalize_path_connections),
          )
        end

        def normalize_path_outputs((ctx, flow_options), *)
          outputs = failure_outputs.merge(ctx[:outputs])
          ctx     = ctx.merge(outputs: outputs)

          return Right, [ctx, flow_options]
        end

        def normalize_path_connections((ctx, flow_options), *)
          connections = failure_connections.merge(ctx[:connections])
          ctx         = ctx.merge(connections: connections)

          return Right, [ctx, flow_options]
        end

        def failure_outputs
          {failure: Activity::Output(Activity::Left, :failure)}
        end
        def failure_connections
          {failure: [Linear::Search.method(:Forward), :failure]}
        end

        Right = Trailblazer::Activity::Right

        def initial_sequence(options)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Path::DSL.initial_sequence(options)
          sequence = Path::DSL.append_end(sequence, task: Activity::End.new(semantic: :failure), magnetic_to: :failure, id: "End.failure")
        end

        class State
          def initialize(normalizers:, initial_sequence:, track_name: :success, left_track_name: :failure, **options)
            @normalizer  = normalizers # compiled normalizers.
            @sequence    = initial_sequence

            # remembers how to call normalizers (e.g. track_color), TaskBuilder
            # remembers sequence

            @framework_options = {track_name: track_name, left_track_name: left_track_name, step_interface_builder: Trailblazer::Activity::TaskBuilder.method(:Binary), adds: [],**options}
          end

          def step(task, options={}, &block)
            options = @normalizer.(:step, framework_options: @framework_options, options: task, user_options: options)

            options, locals = Linear.normalize(options, [:adds]) # DISCUSS: Part of the DSL API.

            [options, *locals[:adds]].each do |insertion|
              @sequence = Linear::DSL.insert_task(@sequence, **insertion)
            end

            @sequence
          end

          def fail(task, options={}, &block)
            options = @normalizer.(:fail, framework_options: @framework_options, options: task, user_options: options)

            options, locals = Linear.normalize(options, [:adds]) # DISCUSS: Part of the DSL API.

            [options, *locals[:adds]].each do |insertion|
              @sequence = Linear::DSL.insert_task(@sequence, **insertion)
            end

            @sequence
          end
        end # State

Linear = Activity::DSL::Linear
        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          fail:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_fail ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        )


        def self.OptionsForState(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), **options)
          initial_sequence = Railway::DSL.initial_sequence(track_name: track_name, end_task: end_task)

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
    end
  end
end
