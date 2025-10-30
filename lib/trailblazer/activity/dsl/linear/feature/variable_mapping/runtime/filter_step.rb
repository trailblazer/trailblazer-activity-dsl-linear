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
              def self.call(task_name, ctx, flow_options, circuit_options) # DISCUSS: we have a completely different set of circuit_options here

                filter_step_exec_context = circuit_options[:filter_step_exec_context]

# FIXME: return real flow_options
                # new_ctx, _flow_options, result = filter_step_exec_context.send(task_name, ctx, flow_options, circuit_options, **ctx.to_h)
                result = filter_step_exec_context.send(task_name, ctx, flow_options, circuit_options, **ctx.to_h)
                # FIXME: new_ctx gets lost?

                signal = Trailblazer::Activity::Right
                if result == Trailblazer::Activity::Left # FIXME: this sucks, of course
                 signal = result
                end

                return ctx, flow_options, signal
              end
            end

            # This is the only public API the DSL part may use.
            # DESIGN NOTE: takes away decisions about internal step structure, such as the optional {#wrap_value_with_hash} step.
            def self.build(filter_activity = MergeVariables, wrap_value_with_hash: true, block_for_filter_step_build: nil, **options_for_step, &block)
              if ! wrap_value_with_hash  # NOTE: this is a compile-time {if}. :D
                filter_activity = Class.new(filter_activity) do
                  step nil, delete: :wrap_value_with_hash unless wrap_value_with_hash # DISCUSS: how do we compose those differing logic flows?
                end
              end

              # current way of adding "features":
              filter_activity.instance_exec(&block_for_filter_step_build) if block_for_filter_step_build

              # Optimization time:
              metal_circuit = filter_activity.to_h[:activity].to_h[:circuit]
              start_task = metal_circuit.to_h[:map].keys[1]
              last_task = metal_circuit.to_h[:map].keys[-3]

# TODO: we can detect termini steps if they only have one output, and set them directly here. for binary, we need to execute the failure terminus.
failure_end = metal_circuit.to_h[:map].keys[-1] # FIXME: we only need this for "deciding" activities.

              metal_circuit.instance_variable_set(:@termini, [last_task, failure_end])
              metal_circuit.instance_variable_set(:@start_task, start_task) # FIXME: we're changing a "different" circuit instance here that's sometimes shared with a superclass.
              # /Optimization time:


              # pp metal_circuit
              # raise

              filter_activity = Class.new(filter_activity)
              options_for_step.each do |key, value|
                filter_activity.instance_variable_set(:"@#{key}", value)
              end

              filter_activity.instance_variable_set(:"@circuit", metal_circuit)

              # new(filter_activity)
              # return metal_circuit, {filter_step_exec_context: filter_activity, runner: MyRunner}
              return filter_activity#, {}
            end

            # class Activity < Trailblazer::Activity::Railway # TODO: performance, Path, Runner, etc.
            _normalizers = Trailblazer::Activity::Railway::DSL::Normalizers

            normalizer_step = _normalizers.instance_variable_get(:@normalizers).fetch(:terminus).instance_variable_get(:@sequence)[5]
            # Remove the task wrapping in the terminus normalizer.... uff.
            _normalizers.instance_variable_get(:@normalizers).fetch(:terminus).instance_variable_get(:@sequence).delete(normalizer_step) # FIXME: make it simpler to add lightweight normalizers.

            Activity = Trailblazer::Activity.Railway(
              termini: {:success => {semantic: :success, id: "End.success", magnetic_to: :success, append_to: nil}, :failure => {semantic: :failure}},
              normalizers: _normalizers,
            ) do
              def self.call(ctx, flow_options, circuit_options)
                @circuit.(ctx, flow_options, circuit_options.merge(runner: MyRunner, filter_step_exec_context: self))
              end

              # FIXME: hack to prevent
              def self.failure(ctx, flow_options, circuit_options, **)
                return ctx, flow_options, nil
              end



              Trailblazer::Activity::DSL::Linear::Normalizer.extend!(self, :step, :pass) do |normalizer|
                _normalizer = Trailblazer::Activity::Adds.(
                  normalizer,
                  [nil, id: "activity.macro_options_with_symbol_task", delete: "activity.macro_options_with_symbol_task"],
                  [nil, id: "activity.wrap_task_with_step_interface", delete: "activity.wrap_task_with_step_interface"],
                )
                # pp _normalizer
              end
            end

            class MergeVariables < Activity
              step :args_for_filter # TODO: rename {#ctx_for_filter}.
              pass :call_filter # filter could return an actual {nil} as a value.
              step :wrap_value_with_hash
              step :merge_variables_into_aggregate

              def self.args_for_filter(ctx, *, application_ctx:, **)
                ctx[:args_for_filter] = application_ctx
              end

              # def self.call_filter(ctx, filter:, args_for_filter:, **)
              def self.call_filter(ctx, flow_options, circuit_options, args_for_filter:, filter: @filter, **)
                _, flow_options, value = filter.(args_for_filter, flow_options, circuit_options)

                ctx[:value] = value # FIXME: this is a "signal to value" filter, we use that in macro, too.
              end

              # def self.wrap_value_with_hash(ctx, value:, write_name:, **)
              def self.wrap_value_with_hash(ctx, *, value:, **)
                ctx[:value] = {@write_name => value}
              end

              def self.merge_variables_into_aggregate(ctx, *, aggregate:, value:, **)
                ctx[:aggregate] = aggregate.merge(value)
              end

              def self.swap_ctx_with_aggregate(ctx, *, aggregate:, **)
                ctx[:args_for_filter] = aggregate
              end

              module Features
                def pass_aggregate(pipe_ctx, *, aggregate:, args_for_filter:, **)
                  merge_into_ctx!(pipe_ctx, args_for_filter, {aggregate: aggregate})
                end

                private def merge_into_ctx!(pipe_ctx, target_ctx, merge_variables) # TODO: improve performance?
                  new_ctx = target_ctx.merge(merge_variables)

                  pipe_ctx[:args_for_filter] = new_ctx
                end
              end

              extend Features

              class Output < MergeVariables
                def self.args_for_filter(ctx, *, returned_ctx:, **)
                  ctx[:args_for_filter] = returned_ctx
                end

                # FIXME: make it {:pass_outer_ctx}.
                # DISCUSS: {:with_outer_ctx} only makes sense with callable filter.
                def self.with_outer_ctx(ctx, *, args_for_filter:, application_ctx:, **)
                  merge_into_ctx!(ctx, args_for_filter, {outer_ctx: application_ctx})
                end
              end
            end # MergeVariables

            # Set variable on ctx if {condition} is true.
            class Conditioned < MergeVariables # currently used for Inject.
              step :evaluate_condition, after: :args_for_filter

              def self.evaluate_condition(ctx, flow_options, circuit_options, args_for_filter:, **)
                # DISCUSS: should we use #call_filter here?
                # call_filter({}, flow_options, circuit_options, filter: @condition, args_for_filter: args_for_filter) # result is value.
                _, flow_options, value = @condition.(args_for_filter, flow_options, circuit_options)
                value === false ? Trailblazer::Activity::Left : value
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

            # DISCUSS: analyze how much logic is needed to introduce this feature.
            class DeleteFromAggregate < Activity
              step :delete_from_aggregate

              def self.delete_from_aggregate(ctx, *, aggregate:, **)
                new_aggregate = aggregate.dup
                new_aggregate.delete(@write_name)

                ctx[:aggregate] = new_aggregate
              end
            end

          end # Filter
        end
      end
    end
  end
end
