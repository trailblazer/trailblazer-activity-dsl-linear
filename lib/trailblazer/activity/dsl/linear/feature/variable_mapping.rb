module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement In(), Inject() and Out(). Deprecates {:input} and {:output}.
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input_id: "task_wrap.input", output_id: "task_wrap.output", **options)
          input, output = VariableMapping.merge_instructions_from_dsl(**options)

          VariableMapping.Extension(input, output)
        end

        module VariableMapping
          # Add our normalizer steps to the strategy's normalizer.
          def self.extend!(strategy, *step_methods) # DISCUSS: should this be implemented in Linear?
            Linear::Normalizer.extend!(strategy, *step_methods) do |normalizer|
              Linear::Normalizer.prepend_to(
                normalizer,
                "activity.wirings",
                steps_for_normalizer
              )
            end
          end

          def self.steps_for_normalizer
            {
              # In(), Out(), {:input}, Inject() feature
              "activity.normalize_input_output_filters"   => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:normalize_input_output_filters)),
              "activity.input_output_dsl"                 => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:input_output_dsl)),
            }
          end

          def self.Extension(input, output, input_id: "task_wrap.input", output_id: "task_wrap.output")
            TaskWrap.Extension(
              [input,  id: input_id,  prepend: "task_wrap.call_task"],
              [output, id: output_id, append: "task_wrap.call_task"]
            )
          end

          # Steps that are added to the DSL normalizer.
          module Normalizer
            # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
            def self.normalize_input_output_filters(ctx, non_symbol_options:, **)
              in_exts     = non_symbol_options.find_all { |k, v| k.is_a?(VariableMapping::DSL::In) || k.is_a?(VariableMapping::DSL::Inject) }
              output_exts = non_symbol_options.find_all { |k, v| k.is_a?(VariableMapping::DSL::Out) }
              return unless in_exts.any? || output_exts.any?

              ctx[:in_filters]  = in_exts
              ctx[:out_filters] = output_exts
            end

            def self.input_output_dsl(ctx, non_symbol_options:, **options)
              # no Input()/Output()/:initial_input_pipeline passed.
              return unless ctx[:in_filters] || ctx[:out_filters] || ctx[:initial_input_pipeline]

              extension = Linear.VariableMapping(**options) # {in_filters:}, {out_filters:} and {:initial_input_pipeline}.

              # TODO: remember {:initial_input_pipeline} when inherit: true.
              # FIXME: defaulting here sucks and should be done above.
              record = Linear::Normalizer::Inherit.Record(((ctx[:in_filters] || []) + (ctx[:out_filters] || [])).to_h, type: :variable_mapping)

              non_symbol_options = non_symbol_options.merge(record)
              non_symbol_options = non_symbol_options.merge(Linear::Strategy.Extension(is_generic: true)  => extension)

              ctx.merge!(
                non_symbol_options: non_symbol_options
              )
            end
          end

          module_function

          # For the input filter we
          #   1. create a separate {Pipeline} instance {pipe}. Depending on the user's options, this might have up to four steps.
          #   2. The {pipe} is run in a lamdba {input}, the lambda returns the pipe's ctx[:input_ctx].
          #   3. The {input} filter in turn is wrapped into an {Activity::TaskWrap::Input} object via {#merge_instructions_for}.
          #   4. The {TaskWrap::Input} instance is then finally placed into the taskWrap as {"task_wrap.input"}.
          #
          # @private
          #
          def merge_instructions_from_dsl(**options)
            pipeline  = DSL.pipe_for_composable_input(**options)  # FIXME: rename filters consistently
            input     = Pipe::Input.new(pipeline)

            output_pipeline = DSL.pipe_for_composable_output(**options)
            output          = Pipe::Output.new(output_pipeline)

            return input, output
          end
        end # VariableMapping
      end
    end
  end
end
