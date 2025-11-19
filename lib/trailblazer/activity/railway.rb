module Trailblazer
  class Activity
    class Railway < DSL::Linear::Strategy
      module DSL
        Linear = Activity::DSL::Linear

        module_function

        def Normalizer(prepend_to_default_outputs: {})
          railway_output_steps = {
            "railway.outputs" => method(:add_failure_output),
          }

          # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
          step_normalizer = Path::DSL.Normalizer(
            prepend_to_default_outputs: railway_output_steps.merge(prepend_to_default_outputs)
          )

          Linear::Normalizer.prepend_to(
            step_normalizer,
            Path::DSL::PREPEND_TO,
            {
              "railway.step.add_failure_connector" => method(:add_failure_connector),
            },
          )
        end

        module Fail
          module_function

          # Change some parts of the step-{Normalizer} pipeline.
          # We're bound to using a very primitive Pipeline API, remember, we don't have
          # a DSL at this point!
          def Normalizer(**options)
            pipeline = Linear::Normalizer.prepend_to( # TODO: replace path.magnetic_to???
              DSL.Normalizer(**options), # grab Railway::DSL::Normalizer.
              Path::DSL::PREPEND_TO,
              {
                "railway.magnetic_to.fail" => Fail.method(:merge_magnetic_to),
              }
            )

            pipeline = Linear::Normalizer.replace(
              pipeline,
              "path.step.add_success_connector",
              ["railway.fail.success_to_failure", Fail.method(:connect_success_to_failure)],
            )
          end

          def merge_magnetic_to(ctx, flow_options, _, **)
            ctx = ctx.merge(magnetic_to: :failure)

            return ctx, flow_options
          end

          SUCCESS_TO_FAILURE_CONNECTOR = {Linear::Normalizer::OutputTuples.Output(:success) => Linear::Strategy.Track(:failure)}

          def connect_success_to_failure(ctx, flow_options, _, **)
            ctx = SUCCESS_TO_FAILURE_CONNECTOR.merge(ctx)

            return ctx, flow_options
          end
        end

        module Pass
          module_function

          def Normalizer(**options)
            Linear::Normalizer.replace(
              DSL.Normalizer(**options), # grab Railway::DSL::Normalizer.
              "railway.step.add_failure_connector",
              ["railway.pass.failure_to_success", Pass.method(:connect_failure_to_success)]
            )
          end

          FAILURE_TO_SUCCESS_CONNECTOR = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:success)}

          def connect_failure_to_success(ctx, flow_options, _, **options)
            Railway::DSL.add_failure_connector(ctx, flow_options, _, **options, failure_connector: FAILURE_TO_SUCCESS_CONNECTOR)
          end
        end

        FAILURE_OUTPUT    = {failure: Activity::Output(Activity::Left, :failure)}
        FAILURE_CONNECTOR = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:failure)}
        PASS_CONNECTOR    = {Linear::Normalizer::OutputTuples.Output(:failure) => Linear::Strategy.Track(:success)}
        FAIL_CONNECTOR    = {Linear::Normalizer::OutputTuples.Output(:success) => Linear::Strategy.Track(:failure)}

        # Add {:failure} output to {:outputs}.
        # This is only called for non-Subprocess steps.
        def add_failure_output(ctx, flow_options, _, outputs:, **)
          ctx = ctx.merge(
            outputs: FAILURE_OUTPUT.merge(outputs)
          )

          return ctx, flow_options
        end

        def add_failure_connector(ctx, flow_options, _, outputs:, failure_connector: FAILURE_CONNECTOR, **)
          return ctx, flow_options unless outputs[:failure] # do not add the default failure connection when we don't have
                                          # a corresponding output.

          ctx = failure_connector.merge(ctx)

          return ctx, flow_options
        end

        Normalizers = Linear::Normalizer::Normalizers.new(
          step:  Railway::DSL.Normalizer(),
          fail:  Railway::DSL::Fail.Normalizer(),
          pass:  Railway::DSL::Pass.Normalizer(),
          terminus: Linear::Normalizer::Terminus.Normalizer(),
        )

        # Default options for build.
        def self.options_for_initialize(failure_end: Activity::End.new(semantic: :failure), **options)
          options = Path::DSL.options_for_initialize(**options)

          layout_instructions = options[:layout_instructions] +
            [[:terminus, task: failure_end, magnetic_to: :failure, id: "End.failure", after: nil]]

          normalizer_options = options[:normalizer_options].merge(failure_end: failure_end) # FIXME: do we need this?

          {
            layout_instructions: layout_instructions,
            normalizers: Normalizers,
            normalizer_options: normalizer_options
          }
        end
      end # DSL

      class << self
        def fail(*args, &block)
          recompile_activity_for(:fail, *args, &block)
        end
        alias left fail

        def pass(*args, &block)
          recompile_activity_for(:pass, *args, &block)
        end
      end

      compile_strategy!(DSL)
      # pp @state.get(:sequence)
    end # Railway

    def self.Railway(**kws, &block)
      Activity::DSL::Linear::Strategy::DSL.Build(Railway, **kws, &block)
    end
  end
end
