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
                  "activity.normalize_input_output_filters" => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:normalize_input_output_filters)),
                  "activity.input_output_dsl"               => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:input_output_dsl)),
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
              return if (options.keys & [:input, :output, :inject, :inject_filters, :in_filters, :output_filters]).empty?

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
            # The overriding {:input} option is set.
            pipeline, has_mono_options, _ = DSL.pipe_for_mono_input(**options)

            if ! has_mono_options
              pipeline = DSL.pipe_for_composable_input(**options)  # FIXME: rename filters consistently
            end

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input  = Pipe::Input.new(pipeline)


            output_pipeline, has_mono_options, _ = DSL.pipe_for_mono_output(**options)

            if ! has_mono_options
              output_pipeline = DSL.pipe_for_composable_output(**options)
            end

            output = Pipe::Output.new(output_pipeline)

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

# < AddVariables
#   Option
#     filter
#   merge_variables

          # Runtime classes
          Filter = Struct.new(:aggregate_step, :filter, :name, :add_variables_class, :variable_name, keyword_init:true)

          # These objects are created via the DSL, keep all i/o steps in a Pipeline
          # and run the latter when being `call`ed.
          module Pipe
            class Input
              def initialize(pipe, id: :vm_original_ctx)
                @pipe = pipe
                @id   = id # DISCUSS: untested.
              end

              def call(wrap_ctx, original_args)
                (original_ctx, original_flow_options), original_circuit_options = original_args

                # let user compute new ctx for the wrapped task.
                pipe_ctx, _ = @pipe.({original_ctx: original_ctx}, [[original_ctx, original_flow_options], original_circuit_options])
                input_ctx   = pipe_ctx[:input_ctx]

                wrap_ctx = wrap_ctx.merge(@id => original_ctx) # remember the original ctx under the key {:vm_original_ctx}.

                # instead of the original Context, pass on the filtered `input_ctx` in the wrap.
                return wrap_ctx, [[input_ctx, original_flow_options], original_circuit_options]
              end
            end

            # API in VariableMapping::Output:
            #   output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)
            # Returns {output_ctx} that is used after taskWrap finished.
            class Output < Input
              # def call(returned_ctx, (original_ctx, returned_flow_options), **original_circuit_options)
                def call(wrap_ctx, original_args)
                  returned_ctx, returned_flow_options = wrap_ctx[:return_args]  # this is the Context returned from {call}ing the wrapped user task.
                  original_ctx                        = wrap_ctx[@id]           # grab the original ctx from before which was set in the {:input} filter.
                  _, original_circuit_options         = original_args

                # let user compute the output.
                pipe_ctx, _ = @pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx}, [[original_ctx, returned_flow_options], original_circuit_options])

                output_ctx  = pipe_ctx[:aggregate]

                wrap_ctx = wrap_ctx.merge(return_args: [output_ctx, returned_flow_options]) # DISCUSS: this won't allow tracing in the taskWrap as we're returning {returned_flow_options} from above.

                return wrap_ctx, original_args
              end
            end
          end

# DISCUSS: improvable sections such as merge vs hash[]=
          def initial_aggregate(wrap_ctx, original_args)
            wrap_ctx = wrap_ctx.merge(aggregate: {})

            return wrap_ctx, original_args
          end

          # Merge all original ctx variables into the new input_ctx.
          # This happens when no {:input} is provided.
          def default_input_ctx(wrap_ctx, original_args)
            default_ctx = wrap_ctx[:original_ctx]

            merge_variables(default_ctx, wrap_ctx, original_args)
          end

          # Input/output Pipeline step that runs the user's {filter} and adds
          # variables to the computed ctx.
          #
          # Basically implements {:input}.
          #


          # Write one particular variable to the {aggregate} using {aggregate[:name] = (value)}.
          #
          # This is much faster than merging a hash, and provides better overriding semantics. (to be done!)
          #
          # @param filter Any circuit-step compatible callable that exposes {#call(args, **circuit_options)}
          #   and returns [value, new_ctx]
          class SetVariable   # TODO: introduce SetVariable without condition.
            def initialize(variable_name:, filter:, user_filter:, name:, condition: ->(*) { true }, **)
              @variable_name = variable_name
              @filter        = filter
              @name = name
              @condition = condition # DISCUSS: adding this as an "optional" step in a "Railway"
            end

            attr_reader :name

            def call(wrap_ctx, original_args)
              # this is the actual logic.
              decision, _ = @condition.(original_args[0]) # DISCUSS: use call_filter here, too

              wrap_ctx = invoke_filter_after_decision(decision, wrap_ctx, original_args)

              return wrap_ctx, original_args
            end

            # @private
            # FIXME: this is not the final API in SetVariable.
            def invoke_filter_after_decision(decision, wrap_ctx, original_args)
              if decision
                value = call_filter(@filter, wrap_ctx, original_args)

                wrap_ctx[:aggregate][@variable_name] = value # yes, we're mutating, but this is ok as we're on some private hash.
              end

              return wrap_ctx
            end

            # Call a filter with a Circuit-Step interface.
            def call_filter(filter, wrap_ctx, (args, circuit_options))
              value, _ = filter.(args, **circuit_options) # circuit-step interface
              value
            end

            class Default < SetVariable
              def initialize(default_filter:, **)
                super
                @default_filter = default_filter
              end

              def invoke_filter_after_decision(decision, wrap_ctx, original_args)
                value =
                  if decision
                    call_filter(@filter, wrap_ctx, original_args)
                  else
                    call_filter(@default_filter, wrap_ctx, original_args)
                  end

                wrap_ctx[:aggregate][@variable_name] = value # yes, we're mutating, but this is ok as we're on some private hash.

                return wrap_ctx
              end
            end
          end

          # TODO: check if this abstraction is worth
          class VariableFromCtx # Filter
            def initialize(variable_name:)
              @variable_name = variable_name
            end

            # Grab @variable_name from {ctx}.
            def call((ctx, _), **) # Circuit-step interface
              return ctx[@variable_name], ctx
            end
          end

          # TODO: check if this abstraction is worth
          class VariablePresent < VariableFromCtx # Filter
            # Grab @variable_name from {ctx} if it's there.
            def call((ctx, _), **) # Circuit-step interface
              return ctx.key?(@variable_name), ctx
            end
          end

          # TODO: check if this abstraction is worth
          class VariableAbsent < VariablePresent # Filter
            # Grab @variable_name from {ctx} if it's there.
            def call((ctx, _), **) # Circuit-step interface
              decision, ctx = super
              return !decision, ctx
            end
          end

# AddVariables: I call something with an Option-interface and run the return value through merge_variables().
          # works on {:aggregate} by (usually) producing a hash fragment that is merged with the existing {:aggregate}
          class AddVariables
            def initialize(filter:, user_filter:, name:, **)
              @filter      = filter # The users input/output filter.
              @user_filter = user_filter # this is for introspection.
              @name = name
            end

            attr_reader :name

            def call(wrap_ctx, original_args)
              ((original_ctx, _), circuit_options) = original_args
              # puts "@@@@@ #{wrap_ctx[:returned_ctx].inspect}"

              # this is the actual logic.
              variables = call_filter(wrap_ctx, original_ctx, circuit_options, original_args)

              VariableMapping.merge_variables(variables, wrap_ctx, original_args)
            end

            def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
              _variables = @filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options)
            end

            class ReadFromAggregate < AddVariables # FIXME: REFACTOR
              def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                new_ctx = wrap_ctx[:aggregate]

                _variables = @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end
            end

            class Output < AddVariables
              def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                new_ctx = wrap_ctx[:returned_ctx]

                @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end

              # Pass {inner_ctx, outer_ctx, **inner_ctx}
              class WithOuterContext < Output
                def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                  new_ctx = wrap_ctx[:returned_ctx]

                  @filter.(new_ctx, original_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
                end
              end

              # Always deletes from {:aggregate}.
              class Delete < AddVariables
                def call(wrap_ctx, original_args)
                  @filter.collect do |name|
                    wrap_ctx[:aggregate].delete(name) # FIXME: we're mutating a hash here!
                  end

                  return wrap_ctx, original_args
                end
              end
            end
          end

          # Finally, create a new input ctx from all the
          # collected input variables.
          # This goes into the step/nested OP.
          def scope(wrap_ctx, original_args)
            ((_, flow_options), _) = original_args

            # this is the actual context passed into the step.
            wrap_ctx[:input_ctx] = Trailblazer::Context(
              wrap_ctx[:aggregate],
              {}, # mutable variables
              flow_options[:context_options]
            )

            return wrap_ctx, original_args
          end

          # Last call in every step. Currently replaces {:input_ctx} by adding variables using {#merge}.
          # DISCUSS: improve here?
          def merge_variables(variables, wrap_ctx, original_args)
            wrap_ctx[:aggregate] = wrap_ctx[:aggregate].merge(variables)

            return wrap_ctx, original_args
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          def default_output_ctx(wrap_ctx, original_args)
            new_ctx = wrap_ctx[:returned_ctx]

            _wrapped, mutable = new_ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

            merge_variables(mutable, wrap_ctx, original_args)
          end

          def merge_with_original(wrap_ctx, original_args)
            original_ctx     = wrap_ctx[:original_ctx]  # outer ctx
            output_variables = wrap_ctx[:aggregate]

            wrap_ctx[:aggregate] = original_ctx.merge(output_variables) # FIXME: use merge_variables()
            # pp wrap_ctx
            return wrap_ctx, original_args
          end
        end # VariableMapping
      end
    end
  end
end
