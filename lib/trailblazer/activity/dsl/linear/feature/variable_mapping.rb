module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input_id: "task_wrap.input", output_id: "task_wrap.output", **options)
          input, output, normalizer_options, non_symbol_options = VariableMapping.merge_instructions_from_dsl(**options)

          extension = VariableMapping.Extension(input, output)

          return TaskWrap::Extension::WrapStatic.new(extension: extension), normalizer_options, non_symbol_options
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
                  "activity.convert_and_deprecate_symbol_options" => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:convert_and_deprecate_symbol_options)),
                  "activity.normalize_input_output_filters"       => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:normalize_input_output_filters)),
                  "activity.input_output_dsl"                     => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:input_output_dsl)),
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
            def self.convert_and_deprecate_symbol_options(ctx, non_symbol_options:, output_with_outer_ctx: nil, **)
              input, output, inject = ctx.delete(:input), ctx.delete(:output), ctx.delete(:inject)
              return unless input || output || inject

              # TODO: warn, deprecate etc
              non_symbol_options.merge!(VariableMapping::DSL.In()      => input) if input

              if output
                options = {}
                options = {with_outer_ctx: output_with_outer_ctx} unless output_with_outer_ctx.nil?

                non_symbol_options.merge!(VariableMapping::DSL.Out(**options) => output)
              end

              if inject
                inject.collect { |filter|
                  filter = filter.is_a?(Symbol) ? [filter] : filter

                  non_symbol_options.merge!(VariableMapping::DSL.Inject()  => filter)
                }
              end

              ctx.merge!(non_symbol_options: non_symbol_options)
            end

            # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
            def self.normalize_input_output_filters(ctx, non_symbol_options:, **)

              input_exts  = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::In) }
              output_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Out) }
              inject_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Inject) }

              return unless input_exts.any? || output_exts.any? || inject_exts.any?

              ctx[:inject_filters] = inject_exts
              ctx[:in_filters]     = input_exts
              ctx[:out_filters]    = output_exts
            end

            def self.input_output_dsl(ctx, extensions: [], **options)
              # no :input/:output/:inject/Input()/Output() passed.
              return if (options.keys & [:inject_filters, :in_filters, :output_filters]).empty?

              extension, normalizer_options, non_symbol_options = Linear.VariableMapping(**options)

              ctx[:extensions] = extensions + [extension] # FIXME: allow {Extension() => extension}
              ctx.merge!(**normalizer_options) # DISCUSS: is there another way of merging variables into ctx?
              ctx[:non_symbol_options].merge!(non_symbol_options)
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

            # default_input
          #  <or>
            # oldway
            #   :input
            #   :inject
            # newway(initial_input_pipeline)
            #   In,Inject
          # => input_pipe
          def merge_instructions_from_dsl(**options)
            pipeline  = DSL.pipe_for_composable_input(**options)  # FIXME: rename filters consistently
            input     = Pipe::Input.new(pipeline)

            output_pipeline = DSL.pipe_for_composable_output(**options)
            output          = Pipe::Output.new(output_pipeline)

            return input, output,
              # normalizer_options:
              {
                variable_mapping_pipelines: [pipeline, output_pipeline],
              },
              # non_symbol_options:
              {
                Linear::Strategy.DataVariable() => :variable_mapping_pipelines # we want to store {:variable_mapping_pipelines} in {Row.data} for later reference.
              }
              # DISCUSS: should we remember the pure pipelines or get it from the compiled extension?
              # store pipe in the extension (via TW::Extension.data)?
          end
        end # VariableMapping
      end
    end
  end
end
