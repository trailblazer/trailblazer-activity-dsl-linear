module Trailblazer
  class Activity
    class Railway < DSL::Linear::Strategy

      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer(prepend_to_default_outputs: [])
          railway_output_steps = {
            "railway.outputs" => Linear::Normalizer.Task(method(:add_failure_output)),
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          step_normalizer = Path::DSL.Normalizer(
            prepend_to_default_outputs: [railway_output_steps, *prepend_to_default_outputs]
          )

          Linear::Normalizer.prepend_to(
            step_normalizer,
            # "activity.wirings",
            "activity.inherit_option", # TODO: do this with all normalizers
            {
              "railway.connections" => Linear::Normalizer.Task(method(:add_failure_connection)),
            },
          )
        end

        # Change some parts of the step-{Normalizer} pipeline.
        # We're bound to using a very primitive Pipeline API, remember, we don't have
        # a DSL at this point!
        def NormalizerForFail(**options)
          pipeline = Linear::Normalizer.prepend_to(
            Normalizer(**options),
            "activity.wirings",
            {
              "railway.magnetic_to.fail" => Linear::Normalizer.Task(Fail.method(:merge_magnetic_to)),
            }
          )

          pipeline = Linear::Normalizer.replace(
            pipeline,
            "path.connections",
            ["railway.connections.fail.success_to_failure", Linear::Normalizer.Task(Fail.method(:connect_success_to_failure))],
          )
        end

        def NormalizerForPass(**options)
          Linear::Normalizer.prepend_to(
            Normalizer(**options),
            "activity.normalize_outputs_from_dsl",
            # "path.connections",
            {"railway.connections.pass.failure_to_success" => Linear::Normalizer.Task(Pass.method(:connect_failure_to_success))}.to_a
          )
        end

        module Fail
          module_function

          def merge_magnetic_to(ctx, **)
            ctx[:magnetic_to] = :failure
          end

          def connect_success_to_failure(ctx, connections: nil, **)
            ctx[:connections] = connections || {success: [Linear::Sequence::Search.method(:Forward), :failure]}
          end
        end

        module Pass
          module_function

          def connect_failure_to_success(ctx, connections:, **)
            ctx[:connections] = connections.merge({failure: [Linear::Sequence::Search.method(:Forward), :success]})
          end
        end

        # Add {:failure} output to {:outputs}.
        # This is only called for non-Subprocess steps.
        # TODO: assert that failure_outputs doesn't override existing {:outputs}
        def add_failure_output(ctx, outputs:, **)
          ctx[:outputs] = FAILURE_OUTPUT.merge(outputs)
        end

        def add_failure_connection(ctx, connections:, outputs:, **)
          return unless outputs[:failure] # do not add the default failure connection when we don't have
                                          # a corresponding output.
          ctx[:connections] = failure_connections.merge(connections)
        end

        FAILURE_OUTPUT = {failure: Activity::Output(Activity::Left, :failure)}

        def failure_connections
          {failure: [Linear::Sequence::Search.method(:Forward), :failure]}
        end

        Normalizers = Linear::Normalizer::Normalizers.new(
          step:  Railway::DSL.Normalizer(),
          fail:  Railway::DSL.NormalizerForFail(),
          pass:  Railway::DSL.NormalizerForPass(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        def options_for_sequence_build(failure_end: Activity::End.new(semantic: :failure), **options)
          failure_terminus_options = [failure_end, magnetic_to: :failure, id: "End.failure", normalizers: Normalizers]

          path_options, path_termini = Path::DSL.options_for_sequence_build(**options)

          return path_options, path_termini + [failure_terminus_options]
        end
      end # DSL

      class << self
        def fail(*args, &block)
          recompile_activity_for(:fail, *args, &block)
        end

        def pass(*args, &block)
          recompile_activity_for(:pass, *args, &block)
        end
      end

      compile_strategy!(DSL, normalizers: DSL::Normalizers)
    end # Railway

    def self.Railway(**options, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(Railway, **options, &block)
    end
  end
end
