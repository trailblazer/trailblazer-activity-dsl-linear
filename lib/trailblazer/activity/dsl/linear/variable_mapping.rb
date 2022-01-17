module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input: nil, output: VariableMapping.default_output, output_with_outer_ctx: false, inject: [], input_filters: [], output_filters: [])
          merge_instructions = VariableMapping.merge_instructions_from_dsl(input: input, output: output, output_with_outer_ctx: output_with_outer_ctx, inject: inject, input_filters: input_filters, output_filters: output_filters)

          TaskWrap::Extension(merge: merge_instructions)
        end

        module VariableMapping
          module_function

          # For the input filter we
          #   1. create a separate {Pipeline} instance {pipe}. Depending on the user's options, this might have up to four steps.
          #   2. The {pipe} is run in a lamdba {input}, the lambda returns the pipe's ctx[:input_ctx].
          #   3. The {input} filter in turn is wrapped into an {Activity::TaskWrap::Input} object via {#merge_instructions_for}.
          #   4. The {TaskWrap::Input} instance is then finally placed into the taskWrap as {"task_wrap.input"}.
          #
          # @private
          def merge_instructions_from_dsl(input:, output:, output_with_outer_ctx:, inject:, input_filters:, output_filters:)
            # FIXME: this could (should?) be in Normalizer?
            inject_passthrough  = inject.find_all { |name| name.is_a?(Symbol) }
            inject_with_default = inject.find { |name| name.is_a?(Hash) } # FIXME: we only support one default hash in the DSL so far.

            input_steps = [
              ["input.init_hash", VariableMapping.method(:initial_input_hash)],
            ]



            # With only injections defined, we do not filter out anything, we use the original ctx
            # and _add_ defaulting for injected variables.
            if !input # only injections defined
              input_steps << ["input.default_input", VariableMapping.method(:default_input_ctx)]
            end

            if input # :input or :input/:inject
              input_filter = Trailblazer::Option(VariableMapping::filter_for(input))

              input_steps << ["input.add_variables", AddVariables.new(input_filter)]
            end

            if inject_passthrough || inject_with_default
              input_steps << ["input.add_injections", VariableMapping.method(:add_injections)] # we now allow one filter per injected variable.
            end

            if inject_passthrough || inject_with_default
              injections = inject.collect do |name|
                if name.is_a?(Symbol)
                  [[name, Trailblazer::Option(->(*) { [false, name] })]] # we don't want defaulting, this return value signalizes "please pass-through, only".
                else # we automatically assume this is a hash of callables
                  name.collect do |_name, filter|
                    [_name, Trailblazer::Option(->(ctx, **kws) { [true, _name, filter.(ctx, **kws)] })] # filter will compute the default value
                  end
                end
              end.flatten(1).to_h
            end

            input_steps << ["input.scope", VariableMapping.method(:scope)]


            pipe = Activity::TaskWrap::Pipeline.new(input_steps)

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input = ->((ctx, flow_options), **circuit_options) do # This filter is called by {TaskWrap::Input#call} in the {activity} gem.
              wrap_ctx, _ = pipe.({injections: injections}, [[ctx, flow_options], circuit_options])

              wrap_ctx[:input_ctx]
            end

            # 1. {} empty input hash
            # 1. input # dynamic => hash
            # 2. input_map       => hash
            # 3. inject          => hash
            # 4. Input::Scoped()

            unscope_class = output_with_outer_ctx ? VariableMapping::Output::Unscoped::WithOuterContext : VariableMapping::Output::Unscoped

            output =
              unscope_class.new(
                Trailblazer::Option(VariableMapping::filter_for(output))
              )

            TaskWrap::VariableMapping.merge_instructions_for(input, output, id: input.object_id) # wraps filters: {Input(input), Output(output)}
          end

# DISCUSS: improvable sections such as merge vs hash[]=
          def initial_input_hash(wrap_ctx, original_args)
            wrap_ctx = wrap_ctx.merge(input_hash: {})

            return wrap_ctx, original_args
          end

          # Merge all original ctx variables into the new input_ctx.
          # This happens when no {:input} is provided.
          def default_input_ctx(wrap_ctx, original_args)
            ((original_ctx, _), _) = original_args

            MergeVariables(original_ctx, wrap_ctx, original_args)
          end

# TODO: test {nil} default
# FIXME: what if you don't want inject but always the value from the config?
          # Add injected variables if they're present on
          # the original, incoming ctx.
          def add_injections(wrap_ctx, original_args)
            name2filter     = wrap_ctx[:injections]
            ((original_ctx, _), circuit_options) = original_args

            injections =
              name2filter.collect do |name, filter|
                # DISCUSS: should we remove {is_defaulted} and infer type from {filter} or the return value?
                is_defaulted, new_name, default_value = filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options) # FIXME: interface?           # {filter} exposes {Option} interface

                original_ctx.key?(name) ?
                  [new_name, original_ctx[name]] : (
                    is_defaulted ? [new_name, default_value] : nil
                  )
              end.compact.to_h # FIXME: are we <2.6 safe here?

            MergeVariables(injections, wrap_ctx, original_args)
          end

          # Input/output Pipeline step that runs the user's {filter} and adds
          # variables to the computed ctx.
          #
          # Basically implements {:input}.
          class AddVariables
            def initialize(input_filter)
              @filter = input_filter # The users input/output filter.
            end

            def call(wrap_ctx, original_args)
              ((original_ctx, _), circuit_options) = original_args

              # this is the actual logic.
              variables = @filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options)

              VariableMapping.MergeVariables(variables, wrap_ctx, original_args)
            end
          end

          # Finally, create a new input ctx from all the
          # collected input variables.
          # This goes into the step/nested OP.
          def scope(wrap_ctx, original_args)
            ((_, flow_options), _) = original_args

            # this is the actual context passed into the step.
            wrap_ctx[:input_ctx] = Trailblazer::Context(
              wrap_ctx[:input_hash],
              {}, # mutable variables
              flow_options[:context_options]
            )

            return wrap_ctx, original_args
          end

          # Last call in every step. Currently replaces {:input_ctx} by adding variables using {#merge}.
          # DISCUSS: improve here?
          def MergeVariables(variables, wrap_ctx, original_args)
            wrap_ctx[:input_hash] = wrap_ctx[:input_hash].merge(variables)

            return wrap_ctx, original_args
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          def default_output
            ->(scoped, **) do
              _wrapped, mutable = scoped.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.
              mutable
            end
          end

          # Returns a filter proc to be called in an Option.
          # @private
          def filter_for(filter)
            if filter.is_a?(::Array) || filter.is_a?(::Hash)
              DSL.filter_from_dsl(filter)
            else
              filter
            end
          end

          # @private
          def output_option_for(option, pass_outer_ctx) # DISCUSS: not sure I like this.

            return option if pass_outer_ctx
            # OutputReceivingInnerCtxOnly =

             # don't pass {outer_ctx}, only {inner_ctx}. this is the default.
            return ->(inner_ctx, outer_ctx, **kws) { option.(inner_ctx, **kws) }
          end


          module DSL
            class Input
            end

            class Output
            end

            # The returned filter compiles a new hash for Scoped/Unscoped that only contains
            # the desired i/o variables.
            def self.filter_from_dsl(map)
              hsh = DSL.hash_for(map)

              ->(incoming_ctx, **kwargs) { Hash[hsh.collect { |from_name, to_name| [to_name, incoming_ctx[from_name]] }] }
            end

            def self.hash_for(ary)
              return ary if ary.instance_of?(::Hash)
              Hash[ary.collect { |name| [name, name] }]
            end
          end

          module Output
            # Merge the resulting {@filter.()} hash back into the original ctx.
            # DISCUSS: do we need the original_ctx as a filter argument?
            class Unscoped
              def initialize(filter)
                @filter = filter
              end

              # The returned hash from {@filter} is merged with the original ctx.
              def call(new_ctx, (original_ctx, flow_options), **circuit_options)
                original_ctx.merge(
                  call_filter(new_ctx, [original_ctx, flow_options], **circuit_options)
                )
              end

              def call_filter(new_ctx, (_original_ctx, _flow_options), **circuit_options)
                # Pass {inner_ctx, **inner_ctx}
                @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end

              class WithOuterContext < Unscoped
                def call_filter(new_ctx, (original_ctx, _flow_options), **circuit_options)
                  # Pass {inner_ctx, outer_ctx, **inner_ctx}
                  @filter.(new_ctx, original_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
                end
              end
            end
          end
        end # VariableMapping
      end
    end
  end
end
