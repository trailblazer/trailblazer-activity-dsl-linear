module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module_function

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
          end # Default

          class Output < SetVariable
            # Call a filter with a Circuit-Step interface.
            def call_filter(filter, wrap_ctx, ((ctx, flow_options), circuit_options))
              new_ctx = wrap_ctx[:returned_ctx]

              value, _ = filter.([new_ctx, flow_options], **circuit_options) # circuit-step interface
              value
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

        # Add a hash of variables to ctx after running a filter (which returns a hash!).
        class AddVariables < SetVariable
          def invoke_filter_after_decision(decision, wrap_ctx, original_args) # FIXME: make this nicer.
            # FIXME: REMOVE {variable_name} from this class, we don't use it here.
            if decision
              variables = call_filter(@filter, wrap_ctx, original_args)

              VariableMapping.merge_variables(variables, wrap_ctx, original_args)
            end

            return wrap_ctx
          end


          class ReadFromAggregate < AddVariables # FIXME: REFACTOR
            def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
              new_ctx = wrap_ctx[:aggregate]

              _variables = @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
            end
          end

          class Output < SetVariable::Output
            def invoke_filter_after_decision(decision, wrap_ctx, original_args) # FIXME: make this nicer.
              # FIXME: REMOVE {variable_name} from this class, we don't use it here.
              if decision
                variables = call_filter(@filter, wrap_ctx, original_args)

                VariableMapping.merge_variables(variables, wrap_ctx, original_args)
              end

              return wrap_ctx
            end

            # Pass {inner_ctx, outer_ctx, **inner_ctx}
            class WithOuterContext < Output
              def call_filter(filter, wrap_ctx, ((original_ctx, _), circuit_options))
                new_ctx = wrap_ctx[:returned_ctx] # FIXME: redundant.

                # Here, due to a stupid API decision, we have to call an Option with two positional args.
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
