module Trailblazer
  class Activity
    module DSL
      class Normalizer
        def self.build_task_wrap_node(ctx, flow_options, _, user_options:, id:, exec_context:, **)
          # raise user_options.inspect
          provider = user_options # FIXME: handle different options.

          step_node_for_call_task = Activity::Step.build(provider, id: id, merge_to_lib_ctx: {exec_context: exec_context})

          task_wrap_pipe = Circuit::Builder.TaskWrap( # DISCUSS: should we return a Node::Scoped here?
            [:"task_wrap.call_task", node: step_node_for_call_task],
            # DISCUSS: other taskWrap steps would go here?
          )

          task_wrap_node = Circuit::Node::Scoped[:"task_wrap.#{id}", task_wrap_pipe, Circuit::Processor]

          return ctx.merge(node: task_wrap_node), flow_options
        end

        def self.build_sequence_row(ctx, flow_options, _, node:, id:, **)
          row = Sequence::Row.new(
            magnetic_to: :success,
            node: node,
            wirings:
              {
                Output.new(Right, :success) => Sequence::Search::Forward.new(:success),
                Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
              },
            data: {id: id},
          )
          return ctx.merge(sequence_row: row), flow_options
        end

        Step = Circuit::Builder.Circuit(
          [:build_task_wrap_node, method(:build_task_wrap_node), connections: {nil => :build_sequence_row}],
          [:build_sequence_row, method(:build_sequence_row), connections: {}],
        )
      end
    end
  end
end
