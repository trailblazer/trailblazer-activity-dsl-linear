module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module_function

        # Runtime classes

        # These objects are created via the DSL, keep all i/o steps in a Pipeline
        # and run the latter as a taskWrap step.

        module Runtime
          def self.build_context((pipe_ctx, _), **)
            flow_options = pipe_ctx[:original_args][0][1]

            # this is the actual context passed into the step.
            pipe_ctx[:input_ctx] = Trailblazer::Context(
              pipe_ctx[:aggregate],
              {}, # mutable variables
              flow_options[:context_options]
            )

            # return pipe_ctx, original_args
            return nil, [pipe_ctx, _]
          end

          # TODO: document
          def self.merge_with_original((pipe_ctx, _), **)
            original_ctx     = pipe_ctx[:original_ctx]  # outer ctx
            output_variables = pipe_ctx[:aggregate]

            # merge_variables(output_variables, pipe_ctx, original_args, original_ctx)
            pipe_ctx[:aggregate] = original_ctx.merge(output_variables)

            return nil, [pipe_ctx, _]
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          #
          # This unscoping is used when there is no explicit Out() filter.
          def self.default_output_ctx((pipe_ctx, _), **)
            new_ctx = pipe_ctx[:returned_ctx]

            _wrapped, mutable = new_ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

            # merge_variables(mutable, pipe_ctx, original_args)
            pipe_ctx[:aggregate] = pipe_ctx[:aggregate].merge(mutable)

            return nil, [pipe_ctx, _]
          end

        end

        module Pipe
          class Input
            def initialize(pipe, id: :vm_original_ctx) # FIXME: remove {id}.
              @pipe = pipe
              @id   = id
            end

            def call(wrap_ctx, original_args)
              (original_ctx, original_flow_options), original_circuit_options = original_args

              # let user compute new ctx for the wrapped task.
              pipe_ctx, _       = @pipe.({original_ctx: original_ctx, aggregate: {}, original_args: original_args}, original_args) # FIXME: remove 2nd arg once we know what we're using.

              ctx_from_input    = pipe_ctx[:input_ctx]

              wrap_ctx = wrap_ctx.merge(@id => original_ctx) # remember the original ctx under the key {@id}.

              # instead of the original Context, pass on the filtered `ctx_from_input` in the wrap.
              return wrap_ctx, [[ctx_from_input, original_flow_options], original_circuit_options]
            end
          end





          class Input_new
            def initialize(pipe)
              @pipe = pipe

              # raise @pipe.to_a.last.inspect
              seq = @pipe.instance_variable_get(:@sequence)
              scope_i = seq.index(seq.last)
              scope = ["input.scope", [Runtime.method(:build_context), {}]]
              seq[scope_i] = scope
              @pipe.instance_variable_set(:@sequence, seq)

              @id = "XXX"
            end

            def call(wrap_ctx, original_args)
              (original_ctx, original_flow_options), original_circuit_options = original_args

              # let user compute new ctx for the wrapped task.
              # pipe_ctx, _       = @pipe.({original_ctx: original_ctx, aggregate: {}, original_args: original_args}, original_args) # FIXME: remove 2nd arg once we know what we're using.

              ctx_for_pipe = {original_ctx: original_ctx, aggregate: {}, original_args: original_args}

              # use our own "runner":
              @pipe.to_a.each do |_, (filter_circuit, call_options)|
                # puts "@@@@@ Pipe, step => #{call_options[:exec_context].instance_variable_get(:@write_name).inspect}"

                signal, (ctx_for_pipe, _) = filter_circuit.([ctx_for_pipe, {}], **call_options)
              end # DISCUSS: what about state? # DISCUSS: here, we can add :start_task, etc.

              ctx_from_input    = ctx_for_pipe[:input_ctx]

              wrap_ctx = wrap_ctx.merge(@id => original_ctx) # remember the original ctx under the key {@id}.

              # instead of the original Context, pass on the filtered `ctx_from_input` in the wrap.
              return wrap_ctx, [[ctx_from_input, original_flow_options], original_circuit_options]
            end
          end

          # API in VariableMapping::Output:
          #   output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)
          # Returns {output_ctx} that is used after taskWrap finished.
          class Output < Input
            def call(wrap_ctx, original_args)
              returned_ctx, returned_flow_options = wrap_ctx[:return_args]  # this is the Context returned from {call}ing the wrapped user task.
              original_ctx                        = wrap_ctx[@id]           # grab the original ctx from before which was set in the {:input} filter.
              _, original_circuit_options         = original_args

              # let user compute the output.
              pipe_ctx, _     = @pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx, aggregate: {}, original_args: original_args}, [[original_ctx, returned_flow_options], original_circuit_options])

              ctx_from_output = pipe_ctx[:aggregate]

              wrap_ctx = wrap_ctx.merge(return_args: [ctx_from_output, returned_flow_options]) # DISCUSS: this won't allow tracing in the taskWrap as we're returning {returned_flow_options} from above.

              return wrap_ctx, original_args
            end
          end

          class Output_new < Input_new
            def initialize(pipe)
              @pipe = pipe

              # raise @pipe.to_a.last.inspect
              seq = @pipe.instance_variable_get(:@sequence)
              scope_i = seq.index(seq.last)
              scope = ["output.scope", [Runtime.method(:merge_with_original), {}]]
              seq[scope_i] = scope
              @pipe.instance_variable_set(:@sequence, seq)

              @id = "XXX"
            end

            def call(wrap_ctx, original_args)
              returned_ctx, returned_flow_options = wrap_ctx[:return_args]  # this is the Context returned from {call}ing the wrapped user task.
              original_ctx                        = wrap_ctx[@id]           # grab the original ctx from before which was set in the {:input} filter.
              # _, original_circuit_options         = original_args


              ctx_for_pipe = {original_ctx: original_ctx, aggregate: {}, original_args: original_args, returned_ctx: returned_ctx}

              # DISCUSS: Problem here: we have a Pipeline comprised of cicuit interface steps, not pipeline interface.
              @pipe.to_a.each do |_, (filter_circuit, call_options)|
                # puts "@@@@@ Pipe, step => #{call_options[:exec_context].instance_variable_get(:@write_name).inspect}"

                signal, (ctx_for_pipe, _) = filter_circuit.([ctx_for_pipe, {}], **call_options)
              end # DISCUSS: what about state? # DISCUSS: here, we can add :start_task, etc.


              # let user compute the output.
              # pipe_ctx, _     = @pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx, aggregate: {}, original_args: original_args}, [[original_ctx, returned_flow_options], original_circuit_options])

              ctx_from_output = ctx_for_pipe[:aggregate]

              wrap_ctx = wrap_ctx.merge(return_args: [ctx_from_output, returned_flow_options]) # DISCUSS: this won't allow tracing in the taskWrap as we're returning {returned_flow_options} from above.

              return wrap_ctx, original_args
            end
          end
        end

        # Merge all original ctx variables into the new input_ctx.
        # This happens when no {:input} is provided.
        def default_input_ctx(wrap_ctx, original_args)
          default_ctx = wrap_ctx[:original_ctx]

          merge_variables(default_ctx, wrap_ctx, original_args)
        end

        # Write one particular variable to the {aggregate} using {aggregate[:name] = (value)}.
        #
        # This is much faster than merging a hash, and provides better overriding semantics. (to be done!)
        #
        # @param filter Any circuit-step compatible callable that exposes {#call(args, **circuit_options)}
        #   and returns [value, new_ctx]
        #

        # Filter
        class VariableFromCtx
          def initialize(variable_name:)
            @variable_name = variable_name
          end

          # Grab @variable_name from {ctx}.
          def call((ctx, _), **) # Circuit-step interface
            return ctx[@variable_name], ctx
          end
        end

        # Filter
        class VariablePresent < VariableFromCtx
          # Grab @variable_name from {ctx} if it's there.
          def call((ctx, _), **) # Circuit-step interface
            return ctx.key?(@variable_name), ctx
          end
        end

        # TODO: * ALL FILTERS and conditions expose circuit-step interface.
        # @param name Identifier for the pipeline
        # Call {user_filter} and set return value as variable on aggregate.
        class SetVariable
          def initialize(write_name:, filter:, user_filter:, name:, _FIXME_wrap_with_hash: false, **) # DISCUSS: what about {user_filter}?
            @write_name  = write_name
            @filter      = filter
            @name        = name
            @_FIXME_wrap_with_hash = _FIXME_wrap_with_hash
          end

          attr_reader :name # TODO: used when adding to pipeline, change to to_h

          def call(wrap_ctx, original_args, filter = @filter)
            wrap_ctx = self.class.set_variable_for_filter(filter, @write_name, wrap_ctx, original_args, @_FIXME_wrap_with_hash)

            return wrap_ctx, original_args
          end

          # Run the actual user's filter and set the computed variable on the aggregate.
          def self.set_variable_for_filter(filter, write_name, wrap_ctx, original_args, _FIXME_wrap_with_hash = false)
            value     = call_filter(filter, wrap_ctx, original_args)

            if _FIXME_wrap_with_hash # FIXME: make this another real step or wrap the user filter in DSL.
              value = {write_name => value}
            end

            wrap_ctx  = set_variable(value, write_name, wrap_ctx, original_args)

            wrap_ctx
          end

          # Call a filter with a Circuit-Step interface.
          def self.call_filter(filter, wrap_ctx, (args, circuit_options))
            value, _ = filter.(args, **circuit_options) # circuit-step interface
            value
          end

          def self.set_variable(variables, write_name, wrap_ctx, original_args)
            wrap_ctx, _ = VariableMapping.merge_variables(variables, wrap_ctx, original_args)
            wrap_ctx
          end

          # Set variable on ctx if {condition} is true.
          class Conditioned < SetVariable
            def initialize(condition:, **options)
              super(**options)

              @condition = condition # DISCUSS: adding this as an "optional" step in a "Railway"
            end

            def call(wrap_ctx, original_args)
              decision, _ = SetVariable.call_filter(@condition, wrap_ctx, original_args)

              return super if decision
              return wrap_ctx, original_args
            end
          end

          # Set variable on ctx if {condition} is true.
          # Otherwise, set default_filter variable on ctx.
          class Default < SetVariable
            def initialize(default_filter:, condition:, **options)
              super(**options)

              @default_filter = default_filter
              @condition      = condition
            end

            def call(wrap_ctx, original_args)
              # FIXME: redundant with Conditioned.
              decision, _ = SetVariable.call_filter(@condition, wrap_ctx, original_args)

              filter = decision ? @filter : @default_filter

              super(wrap_ctx, original_args, filter)
            end
          end # Default

          class PassAggregate < Default
            def self.call_filter(filter, wrap_ctx, original_args)
              ctx, _ = original_args[0]

              new_ctx = ctx.merge(aggregate: wrap_ctx[:aggregate])

              Output.call_filter_with_ctx(filter, new_ctx, wrap_ctx, original_args)
            end
          end

          # TODO: we don't have Out(:variable), yet!
          class Output < SetVariable
            # Call a filter with a Circuit-Step interface.
            def self.call_filter(filter, wrap_ctx, original_args)
              new_ctx = wrap_ctx[:returned_ctx]

              call_filter_with_ctx(filter, new_ctx, wrap_ctx, original_args)
            end

            def self.call_filter_with_ctx(filter, ctx, wrap_ctx, ((_, flow_options), circuit_options))
              SetVariable.call_filter(filter, wrap_ctx, [[ctx, flow_options], circuit_options])
            end
          end

          # Do everything SetVariable does but read from {aggregate}, not from {ctx}.
          # TODO: it would be cool to have this also for AddVariables.
          class ReadFromAggregate < SetVariable
            def self.call_filter(filter, wrap_ctx, original_args)
              new_ctx = wrap_ctx[:aggregate]

              Output.call_filter_with_ctx(filter, new_ctx, wrap_ctx, original_args)
            end
          end

          # @private
          # Always deletes from {:aggregate}.
          class Delete < SetVariable
            def call(wrap_ctx, original_args)
              wrap_ctx[:aggregate].delete(@write_name) # FIXME: we're mutating a hash here!

              return wrap_ctx, original_args
            end
          end
        end # SetVariable

          # Merge hash of Out into aggregate.
          # TODO: deprecate and remove, introduce :with_original_ctx for both ways.
        class Output < SetVariable::Output
          class WithOuterContext < Output
            def self.call_filter(filter, wrap_ctx, ((original_ctx, flow_options), circuit_options))
              new_ctx = wrap_ctx[:returned_ctx]
              new_ctx = new_ctx.merge(outer_ctx: original_ctx)

              Output.call_filter_with_ctx(filter, new_ctx, wrap_ctx, [[original_ctx, flow_options], circuit_options])
            end
          end
        end

        def merge_variables(variables, wrap_ctx, original_args, receiver = wrap_ctx[:aggregate])
          wrap_ctx[:aggregate] = receiver.merge(variables)

          return wrap_ctx, original_args
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

        # @private
        # The default {:output} filter only returns the "mutable" part of the inner ctx.
        # This means only variables added using {inner_ctx[..]=} are merged on the outside.
        #
        # This unscoping is used when there is no explicit Out() filter.
        def default_output_ctx(wrap_ctx, original_args)
          new_ctx = wrap_ctx[:returned_ctx]

          _wrapped, mutable = new_ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

          merge_variables(mutable, wrap_ctx, original_args)
        end

        # This unscoping is used when Out() filters have written to the {aggregate}.
        def merge_with_original(wrap_ctx, original_args)
          original_ctx     = wrap_ctx[:original_ctx]  # outer ctx
          output_variables = wrap_ctx[:aggregate]

          merge_variables(output_variables, wrap_ctx, original_args, original_ctx)
        end
      end # VariableMapping
    end
  end
end
