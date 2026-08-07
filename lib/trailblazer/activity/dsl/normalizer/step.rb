module Trailblazer
  class Activity
    module DSL
      class Normalizer
        # if the {first_arg} is something not nil, we need to convert it to a real Step (node).
        def self.is_step?(ctx, flow_options, _, first_arg:, **)
          return ctx, flow_options, first_arg ? Right : Left
        end

        def self.build_node_for_step(ctx, flow_options, _, first_arg:, id:, exec_context:, **) # FIXME: {:exec_context} is not mandatory.
          step_node_for_call_task = Activity::Step.build(first_arg, id: id, exec_context: exec_context)

          return ctx.merge(node_for_call_task: step_node_for_call_task), flow_options
        end

        def self.build_node_for_task(ctx, flow_options, _, task:, id:, **) # FIXME: nodes shouldn't have ids!
          node_for_task = Circuit::Node[id, task, Circuit::Task::Adapter::LibInterface] # DISCUSS: do we need to change the interface adapter?

          return ctx.merge(node_for_call_task: node_for_task), flow_options
        end

        def self.build_task_wrap_node(ctx, flow_options, _, node_for_call_task:, id:, **)
          task_wrap_pipe = Circuit::Builder.TaskWrap( # DISCUSS: should we return a Node::Scoped here?
            [:"task_wrap.call_task", node: node_for_call_task],
            # DISCUSS: other taskWrap steps would go here?
          )

          # task_wrap_node = Circuit::Node::Scoped[:"#{id}", task_wrap_pipe, Circuit::Processor, merge_to_lib_ctx: [:target_ctx]]
          task_wrap_node = Circuit::Node[:"#{id}", task_wrap_pipe, Circuit::Processor]

          return ctx.merge(node: task_wrap_node), flow_options
        end

        def self.build_sequence_row(ctx, flow_options, _, node:, id:, wirings:, magnetic_to:, **)
          row = Sequence::Row.new(
            magnetic_to: magnetic_to,
            node: node,
            wirings: wirings,
            data: {id: id},
          )
          return ctx.merge(sequence_row: row), flow_options
        end

        def self.compile_adds_for_sequence(ctx, flow_options, _, id:, sequence_row:, adds_insertion_args:, adds_for_sequence: [], **)
          # puts "@@@@@ #{adds_insertion_args.inspect}"
          adds_for_sequence = [
            [id, sequence_row, *adds_insertion_args], # this is the actual row representing the step we're compiling here.
            *adds_for_sequence
          ]

          return ctx.merge(adds_for_sequence: adds_for_sequence), flow_options
        end

        DEFAULT_ADDS_INSERTION_ARGS = [:before, :"End.success"]

        def self.normalize_adds_insertion_args(ctx, flow_options, _, adds_insertion_args: DEFAULT_ADDS_INSERTION_ARGS, **)
          return ctx.merge(adds_insertion_args: adds_insertion_args), flow_options
        end

        def self.normalize_magnetic_to(ctx, flow_options, _, magnetic_to: :success, **)
          return ctx.merge(magnetic_to: magnetic_to), flow_options
        end

        def self.normalize_id_for_step(ctx, flow_options, _, id: nil, first_arg:, **)
          if id.nil?
            id = first_arg # TODO: id for callables, etc?
          end

          return ctx.merge(id: id), flow_options
        end

        # DISCUSS: should we use proper {:connections} hashes here? it seems to work like that.
        Step = Circuit::Builder.Circuit(
          [:is_step?, method(:is_step?), connections: {Left => [:build_node_for_task, Left], Right => [:normalize_id_for_step, Right]}],
          [:normalize_id_for_step, method(:normalize_id_for_step), connections: {nil => :build_node_for_step}], # DISCUSS: what if we need to know what
          [:build_node_for_task, method(:build_node_for_task), connections: {nil => :build_task_wrap_node}],
          [:build_node_for_step, method(:build_node_for_step), connections: {nil => :build_task_wrap_node}],
          [:build_task_wrap_node, method(:build_task_wrap_node)],
          [:normalize_magnetic_to, method(:normalize_magnetic_to)], # DISCUSS: position?
          [:normalize_adds_insertion_args, method(:normalize_adds_insertion_args)], # DISCUSS: position?
          [:build_sequence_row, method(:build_sequence_row)],
          [:compile_adds_for_sequence, method(:compile_adds_for_sequence)],
        )
      end
    end
  end
end
