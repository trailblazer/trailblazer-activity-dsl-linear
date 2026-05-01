require "test_helper"

class TopologyTest < Minitest::Spec
  it "provides #step" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :a, id: :a, exec_context: new
    end

    pp my_topology.config.sequence

  end
end
