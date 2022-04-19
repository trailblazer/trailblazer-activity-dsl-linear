module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    class Railway < DSL::Linear::Strategy

      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer
          path_normalizer =  Path::DSL.Normalizer()

          TaskWrap::Pipeline.prepend(
            path_normalizer,
            "activity.wirings",
            {
              "railway.outputs"     => Linear::Normalizer.Task(method(:normalize_path_outputs)),
              "railway.connections" => Linear::Normalizer.Task(method(:normalize_path_connections)),
            },
          )
        end

        # Change some parts of the step-{Normalizer} pipeline.
        # We're bound to using a very primitive Pipeline API, remember, we don't have
        # a DSL at this point!
        def NormalizerForFail
          pipeline = TaskWrap::Pipeline.prepend(
            Normalizer(),
            "activity.wirings",
            {
              "railway.magnetic_to.fail" => Linear::Normalizer.Task(Fail.method(:merge_magnetic_to)),
            }
          )

          pipeline = TaskWrap::Pipeline.prepend(
            pipeline,
            "path.connections",
            {
              "railway.connections.fail.success_to_failure" => Linear::Normalizer.Task(Fail.method(:connect_success_to_failure)),
            },
            replace: 1 # replace {"path.connections"}
          )
        end

        def NormalizerForPass
          pipeline = TaskWrap::Pipeline.insert_after(
            Normalizer(),
            "path.connections",
            ["railway.connections.pass.failure_to_success", Linear::Normalizer.Task(Pass.method(:connect_failure_to_success))]
          )
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
          _seq = Path::DSL.append_terminus(initial_sequence, failure_end, magnetic_to: :failure, id: "End.failure", normalizers: Normalizers)
        end

        class State < Path::DSL::State
          def fail(*args) # TODO: block
            update_sequence_for!(:fail, *args) # mutate @state
          end

          def pass(*args)
            update_sequence_for!(:pass, *args) # mutate @state
          end
        end # State

        Normalizers = Linear::State::Normalizer.new(
          step:  Railway::DSL.Normalizer(),
          fail:  Railway::DSL.NormalizerForFail(),
          pass:  Railway::DSL.NormalizerForPass(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
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

      initialize!(Railway::DSL::State.build(**DSL.OptionsForState()))
    end # Railway

    def self.Railway(options)
      Class.new(Railway) do
        initialize!(Railway::DSL::State.build(**Railway::DSL.OptionsForState(**options)))
      end
    end
  end
end
