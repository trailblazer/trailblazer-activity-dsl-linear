module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    class Railway
      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def normalizer
          step_options(Activity::Path::DSL.normalizer)
        end

        # Change some parts of the "normal" {normalizer} pipeline.
        # TODO: make this easier, even at this step.

        def normalizer_for_fail
          sequence = normalizer

          id = "railway.magnetic_to.fail"
          task = Fail.method(:merge_magnetic_to)

# TODO: use prepend_to_path
          sequence = Linear::DSL.insert_task(sequence,
            task: TaskBuilder::Binary(task),
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Prepend), "path.wirings"])

          id = "railway.connections.fail.success_to_failure"
          task = Fail.method(:connect_success_to_failure)

          sequence = Linear::DSL.insert_task(sequence,
            task: TaskBuilder::Binary(task),
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Replace), "path.connections"])
        end

        def normalizer_for_pass
          sequence = normalizer

          id = "railway.connections.pass.failure_to_success"
          task = Pass.method(:connect_failure_to_success)

          sequence = Linear::DSL.insert_task(sequence,
            task: TaskBuilder::Binary(task),
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Append), "path.connections"])
        end

        module Fail
          module_function

          def merge_magnetic_to(ctx, **)
            ctx[:magnetic_to] = :failure
          end

          def connect_success_to_failure(ctx, connections: nil, **)
            ctx[:connections] = connections || {success: [Linear::Search.method(:Forward), :failure]}
          end
        end

        module Pass
          module_function

          def connect_failure_to_success(ctx, connections:, **)
            ctx[:connections] = connections.merge({failure: [Linear::Search.method(:Forward), :success]})
          end
        end

        # Add {Railway} steps to normalizer path.
        def step_options(sequence)
          Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            {
              "railway.outputs"     => TaskBuilder::Binary(method(:normalize_path_outputs)),
              "railway.connections" => TaskBuilder::Binary(method(:normalize_path_connections)),
            },

            Linear::Insert.method(:Prepend), "path.wirings" # override where it's added.
          )
        end

        # Add {:failure} output to {:outputs}.
        # TODO: assert that failure_outputs doesn't override existing {:outputs}
        def normalize_path_outputs(ctx, outputs:, **)
          outputs = failure_outputs.merge(outputs)

          ctx[:outputs] = outputs
        end

        def normalize_path_connections(ctx, connections:, **)
          ctx[:connections] = failure_connections.merge(connections)
        end

        def failure_outputs
          {failure: Activity::Output(Activity::Left, :failure)}
        end
        def failure_connections
          {failure: [Linear::Search.method(:Forward), :failure]}
        end

        def initial_sequence(failure_end:, initial_sequence:, **path_options)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Path::DSL.append_end(initial_sequence, task: failure_end, magnetic_to: :failure, id: "End.failure")
        end

        class State < Path::DSL::State
          def fail(*args)
            seq = Linear::Strategy.task_for!(self, :fail, *args) # mutate @state
          end

          def pass(*args)
            seq = Linear::Strategy.task_for!(self, :pass, *args) # mutate @state
          end
        end # Instance

        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          fail:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_fail ),
          pass:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_pass ),
        )

        def self.OptionsForState(normalizers: Normalizers, failure_end: Activity::End.new(semantic: :failure), **options)
          options = Path::DSL.OptionsForState(**options).
            merge(normalizers: normalizers, failure_end: failure_end)

          initial_sequence = Railway::DSL.initial_sequence(failure_end: failure_end, **options)

          {
            **options,
            initial_sequence: initial_sequence,
          }
        end

      end # DSL

      class << self
        private def fail(*args, &block)
          recompile_activity_for(:fail, *args, &block)
        end

        private def pass(*args, &block)
          recompile_activity_for(:pass, *args, &block)
        end
      end

      include DSL::Linear::Helper
      extend DSL::Linear::Strategy

      initialize!(Railway::DSL::State.new(**DSL.OptionsForState()))

    end # Railway

    def self.Railway(options)
      Class.new(Railway) do
        initialize!(Railway::DSL::State.new(**Railway::DSL.OptionsForState(**options)))
      end
    end
  end
end
