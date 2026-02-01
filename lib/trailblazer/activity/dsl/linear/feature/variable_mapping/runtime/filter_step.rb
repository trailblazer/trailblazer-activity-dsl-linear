module Trailblazer
  class Activity
    module DSL::Linear
      module VariableMapping
        module Runtime
          # The idea is, run the FilterStep instance using MyRunner, and execute the tasks directly with the step/kwargs interface.
          class FilterStep
            def initialize(filter_activity)
              @filter_activity = filter_activity
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
              filter_activity = Class.new(filter_activity)

              if ! wrap_value_with_hash  # NOTE: this is a compile-time {if}. :D
                filter_activity.class_eval do
                  step nil, delete: :wrap_value_with_hash unless wrap_value_with_hash # DISCUSS: how do we compose those differing logic flows?
                end
              end

              # current way of adding "features":
              filter_activity.instance_exec(&block_for_filter_step_build) if block_for_filter_step_build

              # Optimization time:
              metal_circuit = filter_activity.to_h[:activity].to_h[:circuit]
              start_task = metal_circuit.to_h[:map].keys[1]
              # last_task = metal_circuit.to_h[:map].keys[-3]

# TODO: we can detect termini steps if they only have one output, and set them directly here. for binary, we need to execute the failure terminus.
failure_end = metal_circuit.to_h[:map].keys[-1] # FIXME: we only need this for "deciding" activities.

# FIXME: last_task only works with Paths.
              # metal_circuit.instance_variable_set(:@termini, [last_task, failure_end])
              metal_circuit.instance_variable_set(:@start_task, start_task) # FIXME: we're changing a "different" circuit instance here that's sometimes shared with a superclass.
              # /Optimization time:


              # pp metal_circuit
              # raise

              options_for_step.each do |key, value|
                filter_activity.instance_variable_set(:"@#{key}", value)
              end

              filter_activity.instance_variable_set(:"@circuit", metal_circuit)

              # new(filter_activity)
              # return metal_circuit, {filter_step_exec_context: filter_activity, runner: MyRunner}
              return filter_activity#, {}
            end

            normalizers = Trailblazer::Activity::Railway::DSL::Normalizers


            # Remove the task wrapping in the terminus normalizer.... uff.
            normalizers =
              Trailblazer::Activity::DSL::Linear::Normalizer.apply(normalizers.to_h, :terminus) do |normalizer|
                Adds.(normalizer, [nil, id: "terminus.normalize_task", delete: "terminus.normalize_task"])
              end
# TODO: allow composing a much smaller normalizer instead of deleting unwanted steps.
            normalizers =
              Trailblazer::Activity::DSL::Linear::Normalizer.apply(normalizers.to_h, :step, :pass, :fail) do |normalizer|
                Adds.(
                  normalizer,
                  [nil, id: "activity.symbol_task_with_circuit_interface", delete: "activity.symbol_task_with_circuit_interface"],
                  [nil, id: "activity.wrap_task_with_step_interface", delete: "activity.wrap_task_with_step_interface"],
                )
              end

            # class Activity < Trailblazer::Activity::Railway # TODO: performance, Path, Runner, etc.
            Activity = Trailblazer::Activity.Railway(
              normalizers: normalizers,
              layout_instructions: [
                [:step, id: "Start.default", task: :start, magnetic_to: nil, after: nil, outputs: {success: Activity.Output(Trailblazer::Activity::Right, :success)}], # DISCUSS: technically, we shouldn't have to define only one output here, but it's easier for Railway and FastTrack.
                [:terminus, id: "End.success", task: :success, magnetic_to: :success, semantic: :success, after: nil],
                [:terminus, id: "End.failure", task: :failure, magnetic_to: :failure, semantic: :failure, after: nil],
              ],
            ) do



              class MyCixRunner
                def self.call(task_name, ctx, flow_options, circuit_options, signal, lib_ctx)
puts "@@@@@ MyCixRunner #{task_name.inspect}"
                  filter_step_exec_context = lib_ctx[:filter_step_exec_context]

  # FIXME: return real flow_options
                  # new_ctx, _flow_options, result = filter_step_exec_context.send(task_name, ctx, flow_options, circuit_options, **ctx.to_h)
                  filter_step_exec_context.send(task_name, ctx, flow_options, circuit_options, signal, lib_ctx, **lib_ctx) # FIXME: redundant cix call
                end
              end
              # def self.call(ctx, flow_options, circuit_options)
              # this vv is the FilterStep Activity class.
              # NOTE: called by Circuit::Processor in Pipe::Input.
              def self.call(ctx, flow_options, circuit_options, signal, lib_ctx, **)
                # @circuit.(ctx, flow_options, circuit_options.merge(runner: MyRunner, filter_step_exec_context: self))
                # @circuit.(ctx, flow_options, circuit_options.merge(runner: MyCixRunner, filter_step_exec_context: self))

                circuit_processor = Circuit::Circuit___.new(@circuit.to_h[:map], @circuit.to_h[:termini], start_task: @circuit.to_h[:start_task])

signal = Trailblazer::Activity::Right # default signal?

                ctx, flow_options, signal, lib_ctx =
                  circuit_processor.(ctx, flow_options, circuit_options.merge(runner: MyCixRunner), signal, lib_ctx.merge(filter_step_exec_context: self))

                return ctx, flow_options, signal, lib_ctx # DISCUSS: discard {lib_ctx}? this Activity is designed to be run within a Processor,
                                                                    # where we pass around the lib_ctx.
              end

              # FIXME: hack so the MyRunner can "execute" the terminus without logic change.
              def self.failure(ctx, flow_options, circuit_options, **)
                return ctx, flow_options, nil
              end
              def self.success(ctx, flow_options, circuit_options, signal, lib_ctx, **) # FIXME: how do we handle termini, how could we detect "last steps"?
                return ctx, flow_options, signal, lib_ctx
              end
            end

            class MergeVariables < Activity
              step :args_for_filter # TODO: rename {#ctx_for_filter}.
              pass :call_filter # filter could return an actual {nil} as a value.
              step :wrap_value_with_hash
              step :merge_variables_into_aggregate

              # def self.args_for_filter(ctx, *, application_ctx:, **)
              #   ctx[:args_for_filter] = application_ctx
              # end
              def self.args_for_filter(ctx, flow_options, _, signal, lib_ctx, **)
                lib_ctx[:args_for_filter] = ctx

                return ctx, flow_options, signal, lib_ctx
              end


              # def self.call_filter(ctx, filter:, args_for_filter:, **)
              def self.call_filter(ctx, flow_options, circuit_options, signal, lib_ctx, args_for_filter:, filter: @filter, **)
                _, flow_options, value = filter.(args_for_filter, flow_options, circuit_options)

                lib_ctx[:value] = value # FIXME: this is a "signal to value" filter, we use that in macro, too.

                return ctx, flow_options, signal, lib_ctx
              end

              # def self.wrap_value_with_hash(ctx, value:, write_name:, **)
              def self.wrap_value_with_hash(ctx, flow_options, _, signal, lib_ctx, value:, **)
                lib_ctx[:value] = {@write_name => value}

                return ctx, flow_options, signal, lib_ctx
              end

              def self.merge_variables_into_aggregate(ctx, flow_options, _, signal, lib_ctx, aggregate:, value:, **)
                lib_ctx[:aggregate] = aggregate.merge(value)

                return ctx, flow_options, signal, lib_ctx
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

                value == false ? Trailblazer::Activity::Left : value
              end
            end

            class Defaulted < Conditioned
              left :set_default_value, Output(:success) => Id(:wrap_value_with_hash), Output(:failure) => Id(:wrap_value_with_hash)

              def self.set_default_value(ctx, flow_options, circuit_options, **options)
                call_filter(ctx, flow_options, circuit_options, **options, filter: @default_filter)
              end
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
