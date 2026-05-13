module Trailblazer
  class Activity
    module DSL
      class Normalizer
        # if the {first_arg} is something not nil, we need to convert it to a real Step (node).
        def self.is_step?(ctx, flow_options, _, first_arg:, **)
          return ctx, flow_options, first_arg ? Right : Left
        end

        def self.build_node_for_step(ctx, flow_options, _, first_arg:, id:, exec_context:, **) # FIXME: {:exec_context} is not mandatory.
          step_node_for_call_task = Activity::Step.build(first_arg, id: id, merge_to_lib_ctx: {exec_context: exec_context})

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

          task_wrap_node = Circuit::Node::Scoped[:"#{id}", task_wrap_pipe, Circuit::Processor]

          return ctx.merge(node: task_wrap_node), flow_options
        end

        def self.FIXME___DEFAULT_WIRINGS
          {
            Output.new(Right, :success) => Sequence::Search::Forward.new(:success),
            # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
          }
        end

        def self.build_sequence_row(ctx, flow_options, _, node:, id:, wirings: FIXME___DEFAULT_WIRINGS(), **)
          row = Sequence::Row.new(
            magnetic_to: :success,
            node: node,
            wirings: wirings,
            data: {id: id},
          )
          return ctx.merge(sequence_row: row), flow_options
        end

        DEFAULT_ADDS_INSERTION_ARGS = [:before, :"task_wrap.End.success"]

        def self.normalize_adds_insertion_args(ctx, flow_options, _, adds_insertion_args: DEFAULT_ADDS_INSERTION_ARGS, **)
          return ctx.merge(adds_insertion_args: adds_insertion_args), flow_options
        end

        Step = Circuit::Builder.Circuit(
          [:is_step?, method(:is_step?), connections: {Left => :build_node_for_task, Right => :build_node_for_step}],
          [:build_node_for_task, method(:build_node_for_task), connections: {nil => :build_task_wrap_node}],
          [:build_node_for_step, method(:build_node_for_step), connections: {nil => :build_task_wrap_node}],
          [:build_task_wrap_node, method(:build_task_wrap_node), connections: {nil => :normalize_adds_insertion_args}],
          [:normalize_adds_insertion_args, method(:normalize_adds_insertion_args), connections: {nil => :build_sequence_row}], # DISCUSS: position?
          [:build_sequence_row, method(:build_sequence_row), connections: {nil => nil}],
        )
      end
    end
  end
end
