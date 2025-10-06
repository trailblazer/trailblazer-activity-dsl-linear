module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module Runtime
          # Fillters are run in a pipe which represents an entire input or output tw "step".
          class FilterStep
            def initialize(filter_activity, options)
              @filter_activity = filter_activity
              @options         = options # DISCUSS: Struct?
            end

            # DISCUSS: could we save this call by using a Pipeline Runner or something? is maybe a delegate faster?
            def call(wrap_ctx, *) # DISCUSS: maybe pipe and activity have the same signature?
              # TODO: use quicker Runner
              _signal, (ctx, _) =  @filter_activity.([wrap_ctx.merge(@options), {}])
              # DISCUSS: maybe pipe and activity have the same signature?
              return ctx, nil
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

              new(filter_activity, options_for_step)
            end

            class DeleteFromAggregate < Trailblazer::Activity::Railway
              step :delete_from_aggregate

              def delete_from_aggregate(ctx, aggregate:, write_name:, **)
                variables_to_keep = aggregate.keys - [write_name]

                ctx[:aggregate] = aggregate.slice(*variables_to_keep)
              end
            end

            class MergeVariables < Trailblazer::Activity::Railway # TODO: performance, Path, Runner, etc.
              step :args_for_filter
              pass :call_filter # filter could return an actual {nil} as a value.
              step :wrap_value_with_hash
              step :merge_variables_into_aggregate

              def args_for_filter(ctx, original_args:, **)
                ctx[:args_for_filter] = original_args
              end

              def call_filter(ctx, filter:, args_for_filter:, **)
                # Calling a filter with a circuit-step interface means we
                # need to pass [[ctx, flow_options], **cicuit_args]
                #
                # DISCUSS: ctx needs to be different sometimes, e.g. in Out, how to do that?
                variable, _ = filter.(args_for_filter[0], **args_for_filter[1]) # circuit-step interface

                ctx[:value] = variable
              end

              def wrap_value_with_hash(ctx, value:, write_name:, **)
                ctx[:value] = {write_name => value}
              end

              def merge_variables_into_aggregate(ctx, aggregate:, value:, **)
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

              include Features

              class Output < MergeVariables
                def args_for_filter(ctx, original_args:, returned_ctx:, **)
                  # super(ctx, **ctx, original_args: [[new_ctx, original_args[0][1]], original_args[1]])
                  ctx[:args_for_filter] = [[returned_ctx, original_args[0][1]], original_args[1]]
                end

                # FIXME: structure!
                # DISCUSS: {:with_outer_ctx} only makes sense with callable filter.
                def with_outer_ctx(ctx, original_args:, **options)
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
