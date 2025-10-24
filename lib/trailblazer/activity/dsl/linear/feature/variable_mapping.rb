  module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement In(), Inject() and Out(). Deprecates {:input} and {:output}.
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input_id: "task_wrap.input", output_id: "task_wrap.output", **options)
          input, output = VariableMapping.merge_instructions_from_dsl(**options)

          VariableMapping.build_task_wrap_extension(input, output)
        end

        module VariableMapping
          # Add our normalizer steps to the strategy's normalizer.
          def self.extend!(strategy, *step_methods) # DISCUSS: should this be implemented in Linear?
            Linear::Normalizer.extend!(strategy, *step_methods) do |normalizer|
              Linear::Normalizer.prepend_to(
                normalizer,
                # "activity.wirings",
                # "extensions.create_extensions_option",
                "step.add_dsl_extensions_to_task_wrap_extensions",
                steps_for_normalizer
              )
            end
          end

          def self.steps_for_normalizer
            {
              # In(), Out(), {:input}, Inject() feature
              "activity.normalize_input_output_filters"   => VariableMapping::Normalizer.method(:normalize_input_output_filters),
              "activity.input_output_dsl"                 => VariableMapping::Normalizer.method(:input_output_dsl),
            }
          end

          def self.build_task_wrap_extension(input, output, input_id: "task_wrap.input", output_id: "task_wrap.output")
            Activity::TaskWrap::Extension(
              [input,  id: input_id,  prepend: "task_wrap.call_task"],
              [output, id: output_id, append: "task_wrap.call_task"]
            )
          end

          # Steps that are added to the DSL normalizer.
          module Normalizer
            # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
            def self.normalize_input_output_filters(ctx, flow_options, _, **)
              in_exts     = ctx.find_all { |k, v| k.is_a?(VariableMapping::DSL::In) || k.is_a?(VariableMapping::DSL::Inject) }
              output_exts = ctx.find_all { |k, v| k.is_a?(VariableMapping::DSL::Out) }
              return ctx, flow_options unless in_exts.any? || output_exts.any?

              ctx = ctx.merge(
                in_filters:  in_exts,
                out_filters: output_exts
              )

              return ctx, flow_options
            end

            def self.input_output_dsl(ctx, flow_options, _, **options) # TODO: rename to {#compile_task_wrap_extensions}.
              # no Input()/Output()/:initial_input_pipeline passed.
              return ctx, flow_options unless ctx[:in_filters] || ctx[:out_filters] || ctx[:initial_input_pipeline]

              extension = Linear.VariableMapping(**options) # {in_filters:}, {out_filters:} and {:initial_input_pipeline}.

              # TODO: remember {:initial_input_pipeline} when inherit: true.
              # FIXME: defaulting here sucks and should be done above.
              record = Linear::Normalizer::Inherit.Record(((ctx[:in_filters] || []) + (ctx[:out_filters] || [])).to_h, type: :variable_mapping)

              ctx = ctx.merge(record)

              ctx = ctx.merge(
                # The ("left") DSL extension got an ID so other Extensions can be evaluated after it.
                Strategy.Extension(is_generic: true, id: "variable_mapping")  => extension
              )

              return ctx, flow_options
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
          def merge_instructions_from_dsl(input_class: Pipe::Input, output_class: Pipe::Output, **options)
            pipeline  = DSL.pipe_for_composable_input(**options)
            # input     = Pipe::Input.new(pipeline)
            input     = input_class.new(pipeline)

            output_pipeline = DSL.pipe_for_composable_output(**options)
            # output          = Pipe::Output.new(output_pipeline)
            output          = output_class.new(output_pipeline)

            return input, output
          end
        end # VariableMapping
      end
    end
  end
end
