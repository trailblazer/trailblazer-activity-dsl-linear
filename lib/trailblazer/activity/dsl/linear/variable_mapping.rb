module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input:  VariableMapping.default_input, output: VariableMapping.default_output)
          input =
            VariableMapping::Input::Scoped.new(
              Trailblazer::Option::KW( VariableMapping::filter_for(input) )
            )

          output =
            VariableMapping::Output::Unscoped.new(
              Trailblazer::Option::KW( VariableMapping::filter_for(output) )
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

          # @private
          def filter_for(filter)
            if filter.is_a?(::Array) || filter.is_a?(::Hash)
              DSL.filter_from_dsl(filter)
            else
              filter
            end
          end

          module DSL
            # The returned filter compiles a new hash for Scoped/Unscoped that only contains
            # the desired i/o variables.
            def self.filter_from_dsl(map)
              hsh = DSL.hash_for(map)

              ->(incoming_ctx, kwargs) { Hash[hsh.collect { |from_name, to_name| [to_name, incoming_ctx[from_name]] }] }
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
                Trailblazer::Context.for_circuit(
                  @filter.(original_ctx, **circuit_options),
                  {},
                  [original_ctx, flow_options], circuit_options # these options for {Context.for} are currently unused.
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
                  @filter.(new_ctx, **circuit_options)
                )
              end
            end
          end
        end # VariableMapping
      end
    end
  end
end
