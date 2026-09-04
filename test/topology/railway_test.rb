require "test_helper"

# Topology is a frontend, it uses a well-defined configuration to produce a builder and then leverages this.

class TopologyRailwayTest < Minitest::Spec
  it "empty Railway" do
    my_railway = Class.new(Trailblazer::Activity::Railway) do
    end

    assert_equal my_railway.to_h[:outputs].keys, [:success, :failure]

    assert_run my_railway.to_h[:circuit], seq: [], terminus: my_railway.to_h[:outputs].fetch(:success).signal
  end

  it "#step" do
    my_railway = Class.new(Trailblazer::Activity::Railway) do
      step :a
      # pp config.builder.sequence
      include T.def_steps(:a)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a], terminus: my_railway.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#left" do
    my_railway = Class.new(Trailblazer::Activity::Railway) do
      step :a
      left :b
      left :c
      step :d
      # pp config.builder.sequence
      include T.def_steps(:a, :b, :c, :d)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a, :d], terminus: my_railway.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left, {b} --> Right
    assert_run my_railway.to_h[:circuit], seq: [1, :a, :b, :c], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
    # {#b} --> Left, {b} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a, :b, :c], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false, b: false}
  end

  it "{#left} is alias for {#fail}" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      fail :b

      include T.def_steps(:a, :b)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:success).signal
    # {#b} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#pass" do
    my_railway = Class.new(Trailblazer::Activity::Railway) do
      pass :a
      step :b
      left :c
      # pp config.builder.sequence
      include T.def_steps(:a, :b, :c, :d)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a, :b], terminus: my_railway.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [:a, :b], terminus: my_railway.to_h[:outputs].fetch(:success).signal

    # {#b} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a, :b, :c], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], b: false}
  end

  # Here, the {:outputs} contains less outputs than in the Topology's defaults.
  # However, our :outputs overrides the default one ...
  it "doesn't add a :success and :failure Output() if they aren't in {:outputs}" do
    my_winning_signal = Class.new(Trailblazer::Activity::Signal)

    my_railway = Class.new(Trailblazer::Activity::Railway) do
      step :a,
        outputs: {
          winning: Trailblazer::Activity::Output.new(my_winning_signal, :winning),
        }, Output(:winning) => Track(:winning)
      step :b
      step :c, magnetic_to: :winning

      include T.def_steps(:a, :b, :c)
    end

    # We return Right and Left, which are unknown:
    _ = assert_raises(KeyError) { assert_run my_railway, seq: [] }
    assert_equal _.message, %(key not found: Trailblazer::Activity::Right)
    _ = assert_raises(KeyError) { assert_run my_railway, seq: [], target_ctx: {seq: [], a: Trailblazer::Activity::Left} }
    assert_equal _.message, %(key not found: Trailblazer::Activity::Left)
    # This works, it's the only :outputs configured.
    assert_run my_railway, seq: [1, :a, :c], terminus: my_railway.to_h[:outputs][:success].signal, target_ctx: {seq: [1], a: my_winning_signal}
  end

  describe "#Railway()" do
    it "Railway() always has one terminus" do
      my_path, _ = Trailblazer::Activity.Railway() do
      end

      assert_equal my_path.to_h[:outputs].inspect, %({:success=>#<struct Trailblazer::Activity::Output signal=#<struct Trailblazer::Activity::Terminus::Success semantic=:success>, semantic=:success>})
    end
  end
end
