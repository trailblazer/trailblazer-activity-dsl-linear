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

  it "doesn't add a :success and :failure Output() if they aren't in {:outputs}" do
    my_winning_signal = Class.new(Trailblazer::Activity::Signal)

    my_path = Class.new(Trailblazer::Activity::Path) do
      step :a,
        outputs: {
          winning: Trailblazer::Activity::Output.new(my_winning_signal, :winning),
        }, Output(:winning) => Track(:winning)
      step :b
      step :c, magnetic_to: :winning

      include T.def_steps(:a, :b, :c)
    end

    # We return Right and Left, which are unknown:
    _ = assert_raises(KeyError) { assert_run my_path, seq: [] }
    assert_equal _.message, %(key not found: Trailblazer::Activity::Right)
    _ = assert_raises(KeyError) { assert_run my_path, seq: [], target_ctx: {seq: [], a: Trailblazer::Activity::Left} }
    assert_equal _.message, %(key not found: Trailblazer::Activity::Left)
    # This works, it's the only :outputs configured.
    assert_run my_path, seq: [1, :a, :c], terminus: my_path.to_h[:outputs][:success].signal, target_ctx: {seq: [1], a: my_winning_signal}
  end

  it "we can use OutputTuples feature" do # DISCUSS: where do we want those tests?
    my_path = Class.new(Trailblazer::Activity::Path) do
      step :a,
        Output(:success) => Id(:c)
      step :b
      step :c

      include T.def_steps(:a, :b, :c)
    end

    assert_equal my_path.to_h[:outputs].keys, [:success]

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :c]
  end
end
