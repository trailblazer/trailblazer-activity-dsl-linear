require "test_helper"

class TopologyPathFunctionTest < Minitest::Spec
  it "empty Path() can be run" do
    my_path, _ = Trailblazer::Activity.Path() do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "Path() always has one terminus" do
    my_path, _ = Trailblazer::Activity.Path() do
    end

    assert_equal my_path.to_h[:outputs].inspect, %({:success=>#<struct Trailblazer::Activity::Output signal=#<struct Trailblazer::Activity::Terminus::Success semantic=:success>, semantic=:success>})
  end

  it "Path() accepts a block" do
    my_exec_context = T.def_steps(:a)

    my_path, _ = Trailblazer::Activity.Path(exec_context: my_exec_context) do
      step :a
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a]
  end

  it "accepts {:track_name}, but you also need to pass :magnetic_to and :failure_track_name to make it work" do
    my_exec_context = T.def_steps(:a, :b, :d)

    # A lot of options necessary here, but this is because no one will ever use this.
    my_path, builder, _ = Trailblazer::Activity.Path(track_name: :green, magnetic_to: :green, failure_track_name: :green, exec_context: my_exec_context) do # DISCUSS:DISCUSS we could shortcut that with Path.default_options_for_builder.
      step :a
      step :b # hopefully, {magnetic_to: :green}.
      step :c, magnetic_to: :success # this shouldn't be part of the path due to wrong track_name.
      step :d, # hopefully, {magnetic_to: :green}.
        wirings: MyTest.wirings_for_terminus
    end

    # First step must be {:magnetic_to} {track_name}.
    assert_equal builder.sequence.to_a.to_h[:a][:magnetic_to], :green

    assert_run my_path.to_h[:circuit], terminus: Trailblazer::Activity::Right, seq: [:a, :b, :d]
    assert_run my_path.to_h[:circuit], terminus: Trailblazer::Activity::Right, seq: [:a, :b, :d], target_ctx: {seq: [], a: false}
    assert_run my_path.to_h[:circuit], terminus: Trailblazer::Activity::Right, seq: [:a, :b, :d], target_ctx: {seq: [], b: false}
  end

  it "we can use OutputTuples feature in Path(), once we include the Helper using {:extends}" do
    my_exec_context = T.def_steps(:a, :b, :c)

    my_path, _ = Trailblazer::Activity::Path(exec_context: my_exec_context, extends: [Trailblazer::Activity::DSL::Topology::Helper]) do
      step :a,
        Output(:success) => Id(:c)
      step :b
      step :c
    end

    assert_equal my_path.to_h[:outputs].keys, [:success]

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :c]
  end
end

class TopologyPathTest < Minitest::Spec
  it "Path always has one terminus" do
    my_path = Class.new(Trailblazer::Activity::Path)

    assert_equal my_path.to_h[:outputs].inspect, %({:success=>#<struct Trailblazer::Activity::Output signal=#<struct Trailblazer::Activity::Terminus::Success semantic=:success>, semantic=:success>})
  end

  it "empty Path can be run" do
    my_path = Class.new(Trailblazer::Activity::Path) do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "we can use OutputTuples features per default" do
    assert_equal Class.new(Trailblazer::Activity::Path).Output(:success).semantic, :success
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
