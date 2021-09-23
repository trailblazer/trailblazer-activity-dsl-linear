module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input: nil, output: VariableMapping.default_output, output_with_outer_ctx: false, inject: nil)
          input_steps = [
            ["input.init_hash", VariableMapping.method(:initial_input_hash)],
          ]

          if !inject && !input
            input_steps << ["input.default_input", VariableMapping.method(:default_input_ctx)]
          end

          if input # :input or :input/:inject
            input_steps << ["input.add_variables", VariableMapping.method(:add_variables)]

            input_filter = Trailblazer::Option(VariableMapping::filter_for(input))
          end

          if inject# && input.nil?
            input_steps << ["input.add_injections", VariableMapping.method(:add_injections)]
          end
          # ->(incoming_ctx, **kwargs)

          input_steps << ["input.scope", VariableMapping.method(:scope)]


          pipe = Activity::TaskWrap::Pipeline.new(input_steps)


          # input =
          #   VariableMapping::Input::Scoped.new(
          #     Trailblazer::Option(VariableMapping::filter_for(input)) # DISCUSS: here is where we have to build a sub-pipeline for input,inject,input_map
          #   )

          # gets wrapped by {VariableMapping::Input} and called there.
          # API: @filter.([ctx, original_flow_options], **original_circuit_options)
          # input = Trailblazer::Option(->(original_ctx, **) {  })
          input = ->((ctx, flow_options), **circuit_options) do
            wrap_ctx, _ = pipe.({inject: inject, input_filter: input_filter}, [[ctx, flow_options], circuit_options])

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

          TaskWrap::Extension(
            merge: TaskWrap::VariableMapping.merge_for(input, output, id: input.object_id), # wraps filters: {Input(input), Output(output)}
          )
        end

        module VariableMapping
          module_function

# FIXME: EXPERIMENTAL
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

          # Add injected variables if they're present on
          # the original, incoming ctx.
          def add_injections(wrap_ctx, original_args)
            injected_variables     = wrap_ctx[:inject]
            ((original_ctx, _), _) = original_args

            injections =
              injected_variables.collect do |var|
                original_ctx.key?(var) ? [var, original_ctx[var]] : nil
              end.compact.to_h # FIXME: are we <2.6 safe here?

            MergeVariables(injections, wrap_ctx, original_args)
          end

          def add_variables(wrap_ctx, original_args)
            filter = wrap_ctx[:input_filter]
            ((original_ctx, _), circuit_options) = original_args

            # this is the actual logic. fuck this
            variables = filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options)

            MergeVariables(variables, wrap_ctx, original_args)
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

          # Last call in every step. Currently replaces {:input_ctx} by *merging* variables.
          # DISCUSS: improve here?
          def MergeVariables(variables, wrap_ctx, original_args)
            wrap_ctx[:input_hash] = wrap_ctx[:input_hash].merge(variables)

            return wrap_ctx, original_args
          end
# FIXME: /EXPERIMENTAL


          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          def default_output
            ->(scoped, **) do
              _wrapped, mutable = scoped.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.
              mutable
            end
          end

          # @private
          def default_input # FIXME: remove
            ->(ctx, **) { ctx }
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

          module Input
            class Scoped
              def initialize(filter)
                @filter = filter
              end

              def call((original_ctx, flow_options), **circuit_options)
                Trailblazer::Context(
                  @filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options), # these are the non-mutable variables
                  {}, # mutable variables
                  flow_options[:context_options]
                )
              end
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

              def call_filter(new_ctx, (original_ctx, flow_options), **circuit_options)
                # Pass {inner_ctx, **inner_ctx}
                @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end

              class WithOuterContext < Unscoped
                def call_filter(new_ctx, (original_ctx, flow_options), **circuit_options)
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
