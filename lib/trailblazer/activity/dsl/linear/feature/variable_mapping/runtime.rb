module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module_function

        # Runtime classes

        # These objects are created via the DSL, keep all i/o steps in a Pipeline
        # and run the latter as a taskWrap step.

        module Runtime
          def self.build_context(wrap_ctx, flow_options, _)
            # this is the actual context passed into the step.
            wrap_ctx[:input_ctx] = Trailblazer::Context(
              wrap_ctx[:aggregate],
              {}, # mutable variables
              flow_options[:context_options]
            )

            # return pipe_ctx, original_args
            return wrap_ctx, flow_options
          end

          # TODO: document
          def self.merge_with_original(wrap_ctx, flow_options, _)
            application_ctx  = wrap_ctx[:application_ctx]  # outer ctx
            output_variables = wrap_ctx[:aggregate]

            # merge_variables(output_variables, wrap_ctx, original_args, application_ctx)
            wrap_ctx[:aggregate] = application_ctx.merge(output_variables)

            return wrap_ctx, flow_options
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          #
          # This unscoping is used when there is no explicit Out() filter.
          def self.default_output_ctx(wrap_ctx, flow_options, _)
            new_ctx = wrap_ctx[:returned_ctx]

            _wrapped, mutable = new_ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

            # merge_variables(mutable, pipe_ctx, original_args)
            wrap_ctx[:aggregate] = wrap_ctx[:aggregate].merge(mutable)

            return wrap_ctx, flow_options
          end

          # Merge all original ctx variables into the new input_ctx.
          # This happens when no In() is provided.
          def self.default_input_ctx(pipe_ctx, flow_options, _)
            default_ctx = pipe_ctx[:application_ctx]

            pipe_ctx[:aggregate] = pipe_ctx[:aggregate].merge(default_ctx)

            return pipe_ctx, flow_options
          end
        end

        module Pipe
          class Input
            def initialize(pipe)
              @pipe = pipe
              @id = "variable_mapping.original_ctx"
            end

            # Called from the official taskWrap, with the official taskWrap interface (wrap_ctx, flow_options, **).
            def call(wrap_ctx, flow_options, circuit_options)
              application_ctx = wrap_ctx[:application_ctx]

              # let user compute new ctx for the wrapped task.
              ctx_for_pipe = {
                application_ctx: application_ctx,
                aggregate:    {},
              }

              # use our own "runner":
              # DISCUSS: executing each filter_circuit here could also be done with a special runner,
              #          one that knows where to find the call_options, etc. this could be a generic Pipeline feature.

          #     @sequence.each do |filter_circuit|
          #       # DISCUSS: {filter_circuit} is not always correct as some "steps" are methods.

          # #     # instead of the original Context, pass on the filtered `ctx_from_input` in the wrap.
          # #     # FIXME: rename to {:application_ctx}
          #       # puts "@@@@@ Pipe, step => #{call_options[:exec_context].instance_variable_get(:@write_name).inspect}"
          #       # for each variable, we're calling a real Circuit instance here. So we kind of need the flow_options argument, in case we ever want to apply tracing.
          #       ctx_for_pipe, flow_options = filter_circuit.(ctx_for_pipe, flow_options, circuit_options) # DISCUSS: pass {circuit_options} here?
          #     end # DISCUSS: what about state? # DISCUSS: here, we   can add :start_task, etc.
              ctx_for_pipe, flow_options = @pipe.(ctx_for_pipe, flow_options, circuit_options)

              ctx_from_input    = ctx_for_pipe[:input_ctx]

              wrap_ctx = wrap_ctx.merge(@id => application_ctx) # remember the original ctx under the key {@id}.

              # instead of the original Context, pass on the filtered `ctx_from_input` in the wrap.
              return wrap_ctx.merge(application_ctx: ctx_from_input), flow_options
            end
          end

          class Output < Input
            def call(wrap_ctx, flow_options, circuit_options)
              returned_ctx, = wrap_ctx[:return_ctx]  # the Context returned from the wrapped (actual) task.

              application_ctx = wrap_ctx[@id] # grab the original ctx from before any In() logic.

              ctx_for_pipe = {
                application_ctx: application_ctx,
                aggregate:       {},
                returned_ctx:    returned_ctx,
              }

              ctx_for_pipe, flow_options = @pipe.(ctx_for_pipe, flow_options, circuit_options)

              ctx_from_output = ctx_for_pipe[:aggregate]

              wrap_ctx = wrap_ctx.merge(return_ctx: ctx_from_output)

              return wrap_ctx, flow_options
            end
          end
        end



        # Write one particular variable to the {aggregate} using {aggregate[:name] = (value)}.
        #
        # This is much faster than merging a hash, and provides better overriding semantics. (to be done!)
        #
        # @param filter Any circuit-step compatible callable that exposes {#call(args, **circuit_options)}
        #   and returns [value, new_ctx]
        #

        # Filter
        class VariableFromCtx # TODO: ReadVariableFromCtx
          def initialize(variable_name:)
            @variable_name = variable_name
          end

          # Grab @variable_name from {ctx}.
          def call(ctx, flow_options, _)
            return ctx, flow_options, ctx[@variable_name]
          end
        end

        # Filter
        class VariablePresent < VariableFromCtx
          # Grab @variable_name from {ctx} if it's there.
          def call(ctx, flow_options, _, **) # Circuit-step interface
            return ctx, flow_options, ctx.key?(@variable_name)
          end
        end
      end # VariableMapping
    end
  end
end
