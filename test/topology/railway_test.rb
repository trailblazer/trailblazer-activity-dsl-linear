require "test_helper"

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
end
