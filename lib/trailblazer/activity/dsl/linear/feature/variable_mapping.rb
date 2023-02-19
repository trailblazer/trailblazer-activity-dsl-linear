module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input_id: "task_wrap.input", output_id: "task_wrap.output", **options)
          input, output = VariableMapping.merge_instructions_from_dsl(**options)
          extension     = VariableMapping.Extension(input, output)

          TaskWrap::Extension::WrapStatic.new(extension: extension)
        end

        module VariableMapping
          # Add our normalizer steps to the strategy's normalizer.
          def self.extend!(strategy, *step_methods) # DISCUSS: should this be implemented in Linear?
            Linear::Normalizer.extend!(strategy, *step_methods) do |normalizer|
              Linear::Normalizer.prepend_to(
                normalizer,
                "activity.wirings",
                {
                   # In(), Out(), {:input}, Inject() feature
                  "activity.convert_symbol_options"           => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:convert_symbol_options)),
                  "activity.normalize_input_output_filters"   => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:normalize_input_output_filters)),
                  "activity.input_output_dsl"                 => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:input_output_dsl)),
                }
              )
            end
          end

          def self.Extension(input, output, input_id: "task_wrap.input", output_id: "task_wrap.output")
            TaskWrap.Extension(
              [input,  id: input_id,  prepend: "task_wrap.call_task"],
              [output, id: output_id, append: "task_wrap.call_task"]
            )
          end

          # Steps that are added to the DSL normalizer.
          module Normalizer
            # TODO: remove me once {:input} API is removed.
            # Convert {:input}, {:output} and {:inject} to In() and friends.
            def self.convert_symbol_options(ctx, non_symbol_options:, output_with_outer_ctx: nil, **)
              input, output, inject = ctx.delete(:input), ctx.delete(:output), ctx.delete(:inject)
              return unless input || output || inject

              dsl_options = {}

              # TODO: warn, deprecate etc
              dsl_options.merge!(VariableMapping::DSL.In() => input) if input

              if output
                options = {}
                options = options.merge(with_outer_ctx: output_with_outer_ctx) unless output_with_outer_ctx.nil?

                dsl_options.merge!(VariableMapping::DSL.Out(**options) => output)
              end

              if inject
                inject.collect do |filter|
                  filter = filter.is_a?(Symbol) ? [filter] : filter

                  dsl_options.merge!(VariableMapping::DSL.Inject()  => filter)
                end
              end

              ctx.merge!(
                non_symbol_options:           non_symbol_options.merge(dsl_options),
                input_output_inject_options:  [{input: input, output: output, inject: inject}, dsl_options], # yes, there were {:input} options.
              )
            end

            # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
            def self.normalize_input_output_filters(ctx, non_symbol_options:, input_output_inject_options: [], **)
              in_exts     = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::In) || k.is_a?(VariableMapping::DSL::Inject) }
              output_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Out) }

              return unless in_exts.any? || output_exts.any?

              deprecate_input_output_inject_option(input_output_inject_options, in_exts, output_exts)

              ctx[:in_filters]     = in_exts
              ctx[:out_filters]    = output_exts
            end

            def self.input_output_dsl(ctx, in_filters: nil, out_filters: nil, non_symbol_options:, **options)
              # no :input/:output/:inject/Input()/Output() passed.
              return unless in_filters || out_filters

              extension = Linear.VariableMapping(in_filters: in_filters, out_filters: out_filters, **options)

              record = Linear::Normalizer::Inherit.Record((in_filters+out_filters).to_h, type: :variable_mapping) # FIXME: just pass one hash around?

              non_symbol_options = non_symbol_options.merge(record)
              non_symbol_options = non_symbol_options.merge(Linear::Strategy.Extension(is_generic: true)  => extension)

              ctx.merge!(
                non_symbol_options: non_symbol_options
              )
            end

            # TODO: remove for TRB 2.2.
            def self.deprecate_input_output_inject_option(input_output_inject_options, *composable_options)
              return unless input_output_inject_options.any?
              options, _dsl_options = input_output_inject_options

              deprecated_options_count = options.find_all { |(name, option)| option }.count + (options[:inject] ? options[:inject].count-1 : 0)
              composable_options_count = composable_options.collect { |options| options.size }.sum

              return if composable_options_count == deprecated_options_count

              Activity::Deprecate.warn Linear::Deprecate.dsl_caller_location, %{You are mixing #{options.inspect} with In(), Out() and Inject().\n#{VariableMapping.deprecation_link}}
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

          def deprecation_link
            %{Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.}
          end
        end # VariableMapping
      end
    end
  end
end
