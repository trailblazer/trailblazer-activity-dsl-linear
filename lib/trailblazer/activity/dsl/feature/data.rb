module Trailblazer
  class Activity
    module DSL
      module Feature
        module Data
          class Variable
          end

          def self.Variable
            Variable.new
          end

          module Normalizer
            module_function

            # Compile the :data field that goes into the sequence row.
            def compile_data(ctx, flow_options, _, **)
              variables_for_data = ctx
                .find_all { |k, v| k.instance_of?(Variable) }
                .to_h
                .values
                .flatten

              ctx = ctx.merge(
                data: variables_for_data.collect { |key| [key, ctx[key]] }.to_h
              )

              return ctx, flow_options
            end

            Node = Circuit::Node[method(:compile_data), Circuit::Task::Adapter::LibInterface]
          end
        end
      end
    end
  end
end
