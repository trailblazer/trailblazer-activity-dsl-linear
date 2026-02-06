module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module_function

        # Runtime classes

        # These objects are created via the DSL, keep all i/o steps in a Pipeline
        # and run the latter as a taskWrap step.

        module Runtime
          def self.build_context(ctx, flow_options, _, signal, lib_ctx, aggregate:, **)
            # this is the actual context passed into the step.
            lib_ctx[:input_ctx] = Trailblazer::Context(
              aggregate,
              {}, # mutable variables
              flow_options[:context_options]
            )

            # return pipe_ctx, original_args
            return ctx, flow_options, signal, lib_ctx
          end

          # TODO: document
          def self.merge_with_original(ctx, flow_options, _, signal, lib_ctx, aggregate:, original_ctx:, **)
            lib_ctx[:aggregate] = original_ctx.merge(aggregate)

            return ctx, flow_options, signal, lib_ctx
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          #
          # This unscoping is used when there is no explicit Out() filter.
          def self.default_output_ctx(ctx, flow_options, _, signal, lib_ctx, aggregate:, **)
            _wrapped, mutable = ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

            lib_ctx[:aggregate] = aggregate.merge(mutable)

            return ctx, flow_options, signal, lib_ctx
          end

          # Merge all original ctx variables into the new input_ctx.
          # This happens when no In() is provided.
          def self.default_input_ctx(ctx, flow_options, _, signal, lib_ctx, aggregate:, **)
            default_ctx = ctx

            lib_ctx[:aggregate] = aggregate.merge(default_ctx)

            return ctx, flow_options, signal, lib_ctx
          end
        end

        module Pipe
          ORIGINAL_CTX_ID = "variable_mapping.original_ctx"

          class Input < Activity::Pipeline
            # Called from the official taskWrap, with the official taskWrap interface (wrap_ctx, flow_options, **).
            # def call(wrap_ctx, flow_options, circuit_options)
            def call(ctx, flow_options, circuit_options, signal, lib_ctx, **)
              # let user compute new ctx for the wrapped task.
              lib_ctx = lib_ctx.merge(
                  aggregate: {}
                )
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
              # ctx_for_pipe, flow_options = @sequence.(ctx_for_pipe, flow_options, circuit_options)

              # ctx_for_pipe, flow_options = super(ctx_for_pipe, flow_options, circuit_options)
              # FIXME: remove this and make this another pipeline step.
              # NOTE: call all steps using the cix interface, this includes the Activitys, too. (which currently doesn't work   )

# FIXME: test {signal}
              ctx, flow_options, _signal, lib_ctx = Circuit::Processor.(@sequence, ctx, flow_options, circuit_options, signal, lib_ctx)

# FIXME: couldn't we do all the below in the last step of Pipe::Input/Output? that would make this class here unnecessary and everything more concise?
              ctx_from_input    = lib_ctx[:input_ctx]

              lib_ctx = lib_ctx.merge(Pipe::ORIGINAL_CTX_ID => ctx) # remember the original ctx under the key {ORIGINAL_CTX_ID}.

              # instead of the original Context, pass on the filtered `ctx_from_input` in the wrap.
              # return wrap_ctx.merge(application_ctx: ctx_from_input), flow_options
              return ctx_from_input, flow_options, signal, lib_ctx
            end
          end

          class Output < Activity::Pipeline
            def call(ctx, flow_options, circuit_options, signal, lib_ctx, **)
              original_ctx = lib_ctx[Pipe::ORIGINAL_CTX_ID] # grab the original ctx from before any In() logic.

              lib_ctx = {
                original_ctx: original_ctx,
                aggregate:       {},
              }

              # ctx_for_pipe, flow_options = @sequence.(ctx_for_pipe, flow_options, circuit_options)
              # ctx_for_pipe, flow_options = super(ctx_for_pipe, flow_options, circuit_options)
              ctx, flow_options, _signal, lib_ctx = Circuit::Processor.(@sequence, ctx, flow_options, circuit_options, signal, lib_ctx)

              ctx_from_output = lib_ctx[:aggregate]

              return ctx_from_output, flow_options, signal, lib_ctx
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
