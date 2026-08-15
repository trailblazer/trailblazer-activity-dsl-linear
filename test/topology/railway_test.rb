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
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a, :b, :c], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
    # {#b} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a, :b, :c], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false, b: false}
  end
end
