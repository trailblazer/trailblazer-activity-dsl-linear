module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module Runtime
          # The idea is, run the FilterStep instance using MyRunner, and execute the tasks directly with the step/kwargs interface.
          class FilterStep
            def initialize(filter_activity)
              @filter_activity = filter_activity
              # @options         = options
              @circuit = filter_activity.to_h[:activity].to_h[:circuit]
            end

            # NOTE: taskWrap/Pipeline runner, invoked directly via Input_new.call{ @sequence.each }
            class MyRunner
              def self.call(task_name, ctx, flow_options, filter_step_exec_context:, **) # DISCUSS: we have a completely different set of circuit_options here

                # DISCUSS: we're doing "atomic calls" here, where we lose tracing, circuit_options, etc, because
                #          we literally don't need or want it anymore. this is for the sake of speed, but on the
                #          other hand we're introducing a "new" signature.
                new_ctx, _ = filter_step_exec_context.send(task_name, ctx, **ctx.to_h) # DISCUSS: no {flow_options} being passed. we're calling an "atomic function" here?!

                # FIXME: we do have Left, too!
                return Trailblazer::Activity::Right, ctx, flow_options
              end
            end

            # This is the only public API the DSL part may use.
            # DESIGN NOTE: takes away decisions about internal step structure, such as the optional {#wrap_value_with_hash} step.
            def self.build(filter_activity = MergeVariables, wrap_value_with_hash: true, **options_for_step, &block)
              if ! wrap_value_with_hash || block_given? # NOTE: this is a compile-time {if}. :D
                filter_activity = Class.new(filter_activity) do
                  step nil, delete: :wrap_value_with_hash unless wrap_value_with_hash # DISCUSS: how do we compose those differing logic flows?
                  instance_exec(&block) if block_given? # FIXME: FUCK THIS
                end
              end

              # Optimization time:
              metal_circuit = filter_activity.to_h[:activity].to_h[:circuit]
              start_task = metal_circuit.to_h[:map].keys[1]
              last_task = metal_circuit.to_h[:map].keys[-3]

              metal_circuit.instance_variable_set(:@termini, [last_task])
              metal_circuit.instance_variable_set(:@start_task, start_task)
              # /Optimization time:


              # pp metal_circuit
              # raise

              filter_activity = Class.new(filter_activity)
              options_for_step.each do |key, value|
                filter_activity.instance_variable_set(:"@#{key}", value)
              end

              # new(filter_activity)
              return metal_circuit, {filter_step_exec_context: filter_activity, runner: MyRunner}
            end

            class DeleteFromAggregate < Trailblazer::Activity::Railway
              step :delete_from_aggregate

              def delete_from_aggregate(ctx, aggregate:, write_name:, **)
                variables_to_keep = aggregate.keys - [write_name]

                ctx[:aggregate] = aggregate.slice(*variables_to_keep)
              end
            end

            class MergeVariables < Trailblazer::Activity::Railway # TODO: performance, Path, Runner, etc.
              Trailblazer::Activity::DSL::Linear::Normalizer.extend!(self, :step, :pass) do |normalizer|
                _normalizer = Trailblazer::Activity::Adds.(
                  normalizer,
                  [nil, id: "activity.macro_options_with_symbol_task", delete: "activity.macro_options_with_symbol_task"],
                  [nil, id: "activity.wrap_task_with_step_interface", delete: "activity.wrap_task_with_step_interface"],
                )
                # pp _normalizer
              end

              step :args_for_filter
              pass :call_filter # filter could return an actual {nil} as a value.
              step :wrap_value_with_hash
              step :merge_variables_into_aggregate

              def self.args_for_filter(wrap_ctx, original_ctx:, **)
                wrap_ctx[:args_for_filter] = [original_ctx]
              end

              # def self.call_filter(ctx, filter:, args_for_filter:, **)
              def self.call_filter(ctx, args_for_filter:, exec_context:, **)
                # raise circuit_options.inspect
                # Calling a filter with a circuit-step interface means we
                # need to pass [[ctx, flow_options], **cicuit_args] BUT WE DON'T WANT TO PASS THE O.G. circuit_options, and maybe also not the flow_options in most cases.
                #
                # DISCUSS: ctx needs to be different sometimes, e.g. in Out, how to do that?
                variable, _ = @filter.(args_for_filter[0], nil, exec_context: exec_context) # FIXME circuit-step interface
                # variable, _ = filter.(args_for_filter[0], **args_for_filter[1]) # circuit-step interface

                ctx[:value] = variable
              end

              # def self.wrap_value_with_hash(ctx, value:, write_name:, **)
              def self.wrap_value_with_hash(ctx, value:, **)
                ctx[:value] = {@write_name => value}
                # ctx[:value] = {write_name => value}
              end

              def self.merge_variables_into_aggregate(ctx, aggregate:, value:, **)
                ctx[:aggregate] = aggregate.merge(value)
              end

              module Features
                # DISCUSS: {:with_outer_ctx} only makes sense with callable filter.
                def pass_aggregate(ctx, aggregate:, **options)
                  merge_into_ctx!(ctx, **options, merge_variables: {aggregate: aggregate})
                end

                # DISCUSS: signature.
                private def merge_into_ctx!(ctx, args_for_filter:, merge_variables:, **) # TODO: improve performance?
                  new_ctx = args_for_filter[0][0].merge(**merge_variables)

                  ctx[:args_for_filter] = [[new_ctx, args_for_filter[0][1]], args_for_filter[1]]
                end

                def swap_ctx_with_aggregate(ctx, args_for_filter:, aggregate:, **)
                  ctx[:args_for_filter] = [[aggregate.freeze, args_for_filter[0][1]], args_for_filter[1]]
                end
              end

              extend Features

              class Output < MergeVariables
                def self.args_for_filter(ctx, original_ctx:, returned_ctx:, **)
                  # super(ctx, **ctx, original_args: [[new_ctx, original_args[0][1]], original_args[1]])
                  ctx[:args_for_filter] = [original_ctx] # FIXME.
                end

                # FIXME: structure!
                # DISCUSS: {:with_outer_ctx} only makes sense with callable filter.
                def self.with_outer_ctx(ctx, original_args:, **options)
                  merge_into_ctx!(ctx, **options, merge_variables: {outer_ctx: original_args[0][0]})
                end
              end

              # Set variable on ctx if {condition} is true.
              class Conditioned < MergeVariables # currently used for Inject.
                step :evaluate_condition, after: :args_for_filter

                def evaluate_condition(ctx, condition:, args_for_filter:, **)
                  # DISCUSS: should we use #call_filter here?
                  call_filter({}, filter: condition, args_for_filter: args_for_filter) # result is value.
                end
              end

              class Defaulted < Conditioned
                left :set_default_value
                left :wrap_value_with_hash, id: :wrap_value_with_hash_for_default
                left :merge_variables_into_aggregate, id: :merge_variables_into_aggregate_for_default

                def set_default_value(ctx, filter_for_default:, **options)
                  call_filter(ctx, **options, filter: filter_for_default)
                end

                include Features

              end
            end
          end # Filter
        end
      end
    end
  end
end
