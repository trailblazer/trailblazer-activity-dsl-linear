require "test_helper"

class TopologyTest < Minitest::Spec
  it "#step accepts {:task}" do

  end

  it "#step accepts {:magnetic_to}" do

  end

  it "provides #step" do
    success = nil
    my_topology = Class.new(Trailblazer::Activity) do
      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"task_wrap.End.success", magnetic_to: :success,
        adds_insertion_args: [:after],
        wirings: {Trailblazer::Activity::Output.new(success, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}

      step :a, id: :a, exec_context: new

      include T.def_steps(:a)
    end

    # pp my_topology.config.sequence
    # pp my_topology.config.circuit

    my_topology_node = Trailblazer::Circuit::Node[:create, my_topology.config.circuit, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      my_topology_node,
      {},
      {application_ctx: {seq: []}},
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_run my_topology_node, node: true,
      seq: [:a],
      terminus: success
  end

  it "inheritance doesn't bleed into parents" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :a, id: :a, exec_context: new

      include T.def_steps(:a)
    end

    my_child_activity = Class.new(my_topology)
    my_child_activity_with_b_step = Class.new(my_topology) do
      step :b, id: :b, exec_context: new

      include T.def_steps(:b)
    end


    assert_run my_topology.config.circuit, seq: [:a], terminus: my_topology.config.circuit.nodes.values.last.task
    assert_run my_child_activity.config.circuit, seq: [:a], terminus: my_child_activity.config.circuit.nodes.values.last.task
    pp my_child_activity_with_b_step.config.circuit.flow_map
    assert_run my_child_activity_with_b_step.config.circuit, seq: [:a], terminus: my_child_activity_with_b_step.config.circuit.nodes.values.last.task
  end
end
