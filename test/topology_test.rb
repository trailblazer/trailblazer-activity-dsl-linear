require "test_helper"

class TopologyTest < Minitest::Spec
  it "provides #step" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :a
    end

    pp my_topology.config.sequence

  end
end
