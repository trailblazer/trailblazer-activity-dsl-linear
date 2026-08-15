require "test_helper"

class TopologyPathTest < Minitest::Spec
  it "empty Path can be run" do
    my_path = Class.new(Trailblazer::Activity::Path) do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "empty Path() can be run" do
    my_path, _ = Trailblazer::Activity::Path() do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "step can return Right and Left" do
    my_path = Class.new(Trailblazer::Activity::Path) do
      # config.builder = config.builder.clone(merge: {exec_context: new.freeze}) # done via {Topology.inherited}.
      step :a
      step :b

      include T.def_steps(:a, :b)
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :b]

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [1, :a, :b], target_ctx: {seq: [1], a: Trailblazer::Activity::Left}
  end

  it "step can return Left" do
    # see above
  end
end
