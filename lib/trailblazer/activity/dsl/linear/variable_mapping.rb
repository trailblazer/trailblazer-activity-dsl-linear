module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input: VariableMapping.default_input, output: VariableMapping.default_output, output_with_outer_ctx: false)
          input =
            VariableMapping::Input::Scoped.new(
              Trailblazer::Option(VariableMapping::filter_for(input))
            )

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

          # @private
          def default_output
            ->(scoped, **) do
              _wrapped, mutable = scoped.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.
              mutable
            end
          end

          # @private
          def default_input
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
                  @filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options),
                  {},
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
