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
            Path::DSL::PREPEND_TO,
            {
              "railway.step.add_failure_connector" => Linear::Normalizer.Task(method(:add_failure_connector)),
            },
          )
        end

        # Change some parts of the step-{Normalizer} pipeline.
        # We're bound to using a very primitive Pipeline API, remember, we don't have
        # a DSL at this point!
        def NormalizerForFail(**options)
          pipeline = Linear::Normalizer.prepend_to(
            Normalizer(**options),
            Path::DSL::PREPEND_TO,
            {
              "railway.magnetic_to.fail" => Linear::Normalizer.Task(Fail.method(:merge_magnetic_to)),
            }
          )

          pipeline = Linear::Normalizer.replace(
            pipeline,
            "path.connections",
            ["railway.fail.success_to_failure", Linear::Normalizer.Task(Fail.method(:connect_success_to_failure))],
          )
        end

        def NormalizerForPass(**options)
          Linear::Normalizer.replace(
            Normalizer(**options),
            "railway.step.add_failure_connector",
            ["railway.pass.failure_to_success", Linear::Normalizer.Task(Pass.method(:connect_failure_to_success))]
          )
        end

        module Fail
          module_function

          def merge_magnetic_to(ctx, **)
            ctx[:magnetic_to] = :failure
          end

          SUCCESS_TO_FAILURE_CONNECTOR = {Linear::Normalizer.Output(:success) => Linear::Strategy.Track(:failure)}

          def connect_success_to_failure(ctx, non_symbol_options:, **)
            ctx[:non_symbol_options] = SUCCESS_TO_FAILURE_CONNECTOR.merge(non_symbol_options)
          end
        end

        module Pass
          module_function

          FAILURE_TO_SUCCESS_CONNECTOR = {Linear::Normalizer.Output(:failure) => Linear::Strategy.Track(:success)}

          def connect_failure_to_success(ctx, non_symbol_options:, **)
            ctx[:non_symbol_options] = FAILURE_TO_SUCCESS_CONNECTOR.merge(non_symbol_options)
          end
        end

        FAILURE_OUTPUT    = {failure: Activity::Output(Activity::Left, :failure)}
        FAILURE_CONNECTOR = {Linear::Normalizer.Output(:failure) => Linear::Strategy.Track(:failure)}
        PASS_CONNECTOR    = {Linear::Normalizer.Output(:failure) => Linear::Strategy.Track(:success)}
        FAIL_CONNECTOR    = {Linear::Normalizer.Output(:success) => Linear::Strategy.Track(:failure)}

        # Add {:failure} output to {:outputs}.
        # This is only called for non-Subprocess steps.
        def add_failure_output(ctx, outputs:, **)
          ctx[:outputs] = FAILURE_OUTPUT.merge(outputs)
        end

        def add_failure_connector(ctx, outputs:, non_symbol_options:, **)
          return unless outputs[:failure] # do not add the default failure connection when we don't have
                                          # a corresponding output.

          ctx[:non_symbol_options] = FAILURE_CONNECTOR.merge(non_symbol_options)
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
