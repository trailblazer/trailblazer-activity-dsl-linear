require "test_helper"

class TopologyTest < Minitest::Spec
  it "provides #step" do
    my_topology = Class.new(Trailblazer::Activity) do
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

    assert_equal lib_ctx, {}
    assert_equal flow_options, {:application_ctx=>{:seq=>[:a]}}
    assert_equal signal, my_topology.config.circuit.nodes.values.last.task
  end
end
