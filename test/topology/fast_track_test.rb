require "test_helper"

class TopologyFastTrackTest < Minitest::Spec
  it "empty FastTrack" do
    my_railway = Class.new(Trailblazer::Activity::FastTrack) do
    end

    assert_equal my_railway.to_h[:outputs].keys, [:success, :failure, :pass_fast, :fail_fast]

    assert_run my_railway.to_h[:circuit], seq: [], terminus: my_railway.to_h[:outputs].fetch(:success).signal
  end

  it "#step" do
    my_railway = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      # pp config.builder.sequence
      include T.def_steps(:a)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a], terminus: my_railway.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#step, pass_fast: true" do
    my_railway = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, pass_fast: true
      step :b
      # pp config.builder.sequence
      include T.def_steps(:a, :b)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a], terminus: my_railway.to_h[:outputs].fetch(:pass_fast).signal
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a], terminus: my_railway.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#step, fail_fast: true" do
    my_railway = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, fail_fast: true
      step :b
      left :c
      # pp config.builder.sequence
      include T.def_steps(:a, :b, :c)
    end

    # {#a} --> Right
    assert_run my_railway.to_h[:circuit], seq: [:a, :b], terminus: my_railway.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_railway.to_h[:circuit], seq: [1, :a], terminus: my_railway.to_h[:outputs].fetch(:fail_fast).signal, target_ctx: {seq: [1], a: false}
  end
end
