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

  it "#step, pass_fast: true, fail_fast: true" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, pass_fast: true, fail_fast: true
      step :b
      left :c

      include T.def_steps(:a, :b, :c)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal, target_ctx: {seq: [1], a: false}
  end

  it "we can reference the existing FastTrack termini" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, Output(:success) => Terminus(:fail_fast)
      step :b
      left :c

      include T.def_steps(:a, :b, :c)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal
    # {#a} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :c], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
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

  it "#left, fail_fast: true" do
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

  it "{#left} is alias for {#fail}" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      fail :b

      include T.def_steps(:a, :b)
    end

    # {#a} --> Right
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:success).signal
    # {#b} --> Left
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
  end

  it "#step, fast_track: true, step returns a FastTrack::Signal" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, fast_track: true
      left :b
      step :c

      include T.def_steps(:a, :b, :c)
    end

    # a --> true
    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: my_activity.to_h[:outputs].fetch(:success).signal, target_ctx: {seq: []}
    # a --> false
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
    # a --> PassFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::PassFast}
    # a --> FailFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::FailFast}
  end


  it "returning a FastTrack signal directly from a circuit interface task" do
    my_exec_context = T.def_tasks(:a, :b, :c)

    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step task: my_exec_context.method(:a), id: :a, fast_track: true
      left task: my_exec_context.method(:b), id: :b
      step task: my_exec_context.method(:c), id: :c
    end

    # a --> true
    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: my_activity.to_h[:outputs].fetch(:success).signal, target_ctx: {seq: []}
    # a --> false
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: Trailblazer::Activity::Left}
    # a --> PassFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::PassFast}
    # a --> FailFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::FailFast}
  end

  it "#step, fast_track: true, step returns a FastTrack::Terminus (Subprocess)" do
    my_fast_track_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a, fast_track: true # we may return four different signals.

      include T.def_steps(:a)
    end

    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step task: my_fast_track_activity, outputs: my_fast_track_activity.to_h[:outputs],
        fast_track: true, id: :a, adapter: Trailblazer::Circuit::Processor
      left :b
      step :c

      include T.def_steps(:b, :c)
    end

    # a --> true
    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: my_activity.to_h[:outputs].fetch(:success).signal, target_ctx: {seq: []}
    # a --> false
    assert_run my_activity.to_h[:circuit], seq: [1, :a, :b], terminus: my_activity.to_h[:outputs].fetch(:failure).signal, target_ctx: {seq: [1], a: false}
    # a --> PassFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:pass_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::PassFast}
    # a --> FailFast
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:fail_fast).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::FailFast}
  end

  # DISCUSS: what happens here?
  it "#fail, pass_fast: true" do

  end

  # DISCUSS: this test is not really necessary.
  it "without {fast_track: true} there is no {Output(:pass_fast)} for scalar task" do
    exception = assert_raises do
      activity = Class.new(Trailblazer::Activity::FastTrack) do
        step :model, Output(:pass_fast) => Track(:failure)
      end
    end

    assert_equal CU.inspect(exception.message), %{No `pass_fast` output found for :model and outputs {:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>}}
  end

  it "you can add the {:pass_fast}/{:fail_fast} outputs manually, but only for {Subprocess} or when the {:outputs} contains those special semantics." do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a,
        Output(:pass_fast) => Track(:failure),
        outputs: { # normally, this is provided by Subprocess().
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
          pass_fast: Trailblazer::Activity::Output.new(Trailblazer::Activity::FastTrack::Signal::PassFast, :pass_fast),
        }

      include T.def_steps(:a)
    end

    assert_run my_activity, seq: [:a], terminus: my_activity.to_h[:outputs].fetch(:success).signal
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:failure).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::Left}
    assert_run my_activity.to_h[:circuit], seq: [1, :a], terminus: my_activity.to_h[:outputs].fetch(:failure).signal,
      target_ctx: {seq: [1], a: Trailblazer::Activity::FastTrack::Signal::PassFast}
  end
end
