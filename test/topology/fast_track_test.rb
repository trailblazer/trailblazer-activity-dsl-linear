require "test_helper"

class TopologyFastTrackTest < Minitest::Spec
  it "empty FastTrack" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
    end

    assert_equal my_activity.to_h[:outputs].keys, [:success, :failure, :pass_fast, :fail_fast]

    assert_run my_activity.to_h[:circuit], seq: [], terminus: my_activity.to_h[:outputs].fetch(:success).signal
  end

  it "#step" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      # pp config.builder.sequence
      include T.def_steps(:a)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#step, pass_fast: true" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, pass_fast: true
      step :b

      include T.def_steps(:a, :b)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#step, fail_fast: true" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, fail_fast: true
      step :b
      left :c

      include T.def_steps(:a, :b, :c)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: my_activity.to_h[:outputs].fetch(:success).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal, target_ctx: {seq: [1], a: false}
  end

  it "#pass, pass_fast: true" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      pass :a, pass_fast: true
      step :b
      left :c

      include T.def_steps(:a, :b, :c)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal, target_ctx: {seq: [1], a: false}
  end

  it "#fail, fail_fast: true" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      left :b, fail_fast: true
      left :c

      include T.def_steps(:a, :b, :c)
    end

    # Both Right and Left go to fail_fast from {#b}
    # {#b} --> Right
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal, target_ctx: {seq: [1], a: false}
    # {#b} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal, target_ctx: {seq: [1], a: false}
  end

  it "returning a FastTrack signal" do
  raise "also, from a ciccuit interface task"
  end
end
