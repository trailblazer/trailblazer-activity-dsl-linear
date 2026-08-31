require "test_helper"

class SubprocessTest < Minitest::Spec
  def self.my_nested_activity(termini: [:success, :failure])
    Class.new(Trailblazer::Activity::FastTrack) do
      step :b, fast_track: true

      include T.def_steps(:b)
    end
  end

  it "#Subprocess(FastTrack) with Path" do
    my_activity = Class.new(Trailblazer::Activity::Path) do
      step :a
      step Subprocess(SubprocessTest.my_nested_activity), id: "FIXME, no ID automatically assigned"
      step :c

      include T.def_steps(:a, :c)
    end

    assert_run my_activity, terminus: success_terminus = my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c]
    assert_run my_activity, terminus: success_terminus, seq: [:a, :b, :c], target_ctx: {seq: [], b: Trailblazer::Activity::Left}
    # even though we provide for {:outputs}, the fast tracks are ignored by Path.
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::PassFast} }
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::FailFast} }
  end

  it "#Subprocess(FastTrack) with Railway" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step Subprocess(SubprocessTest.my_nested_activity), id: "FIXME, no ID automatically assigned"
      step :c

      include T.def_steps(:a, :c)
    end

    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c]
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:failure].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::Left}
    # even though we provide for {:outputs}, the fast tracks are ignored by Railway.
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::PassFast} }
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::FailFast} }
  end

  it "#Subprocess(FastTrack) with FastTrack" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      step Subprocess(SubprocessTest.my_nested_activity), id: "FIXME, no ID automatically assigned"
      step :c

      include T.def_steps(:a, :c)
    end

    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c]
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:failure].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::Left}
    # even though we provide for {:outputs}, the fast tracks are ignored by FastTrack.
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::PassFast} }
    assert_raises(KeyError) { assert_run my_activity, seq: nil, target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::FailFast} }
  end

  it "#Subprocess(FastTrack) with FastTrack and {fast_track: true} wires all nested termini properly" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      step :a
      step Subprocess(SubprocessTest.my_nested_activity),
        id: "FIXME, no ID automatically assigned",
        fast_track: true
      step :c

      include T.def_steps(:a, :c)
    end

    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c]
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:failure].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::Left}
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:fail_fast].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::FailFast}
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:pass_fast].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::FastTrack::Signal::PassFast}
  end

  # NOTE: This test is not really necessary and could be moved to test/docs.
  it "Subprocess with custom output obviously overrides the step's default {:outputs}" do
    MyReceivedSignal = Class.new(Trailblazer::Activity::Signal)

    my_nested_activity = Class.new(Trailblazer::Activity::Railway) do
      step :b, Output(:received, signal: MyReceivedSignal) => Terminus(:received)

      include T.def_steps(:b)
    end

    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step Subprocess(my_nested_activity), id: "FIXME, no ID automatically assigned",
        Output(:received) => Track(:received)
      step :c, magnetic_to: :received
      step :d

      include T.def_steps(:a, :c, :d)
    end

    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :d]
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c, :d], target_ctx: {seq: [], b: MyReceivedSignal}
  end

  it "#Subprocess() with Railway and {strict: true}" do
    skip "as long as we don't have exceptions on missing Forward targets, this option doesn't make sense"
    MyReceivedSignal = Class.new(Trailblazer::Activity::Signal)

    my_nested_activity = Class.new(Trailblazer::Activity::Railway) do
      step :b, Output(:received, signal: MyReceivedSignal) => Terminus(:received)

      include T.def_steps(:b)
    end

    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step Subprocess(my_nested_activity,
        strict: true), id: "FIXME, no ID automatically assigned"
      step :c
      step :d, magnetic_to: :received # FIXME: otherwise, the nested activity will stop on MyReceivedSignal

      include T.def_steps(:a, :c, :d)
    end

    # pp my_activity.to_h

    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b, :c]
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:failure].signal, seq: [:a, :b], target_ctx: {seq: [], b: Trailblazer::Activity::Left}
    assert_run my_activity, terminus: my_activity.to_h[:outputs][:success].signal, seq: [:a, :b], target_ctx: {seq: [], b: MyReceivedSignal}
  end

  describe "{:patch}" do
    it "replaces deeply nested activity" do
      advance = Class.new(Trailblazer::Activity::Path) do
        step :g
        step :f

        include T.def_steps(:g, :f)
      end

      controller = Class.new(Trailblazer::Activity::Path) do
        step Subprocess(advance), id: :advance
        step :d

        include T.def_steps(:d)
      end

      my_controller = Class.new(Trailblazer::Activity::Path) do
        step :c
        step Subprocess(controller), id: :controller

        include T.def_steps(:c)
      end

      our_controller = Class.new(Trailblazer::Activity::Path) do
        step :b
        step Subprocess(
            my_controller,
            patch: {
              [:controller, :advance] => -> { step T.def_steps(:a).method(:a), before: :f },
              [:controller] => -> { step T.def_steps(:x).method(:x), after: :advance },
            }
          ), id: :my_controller

        include T.def_steps(:b)
      end

      # We added {:a} and {:x}.
      assert_run our_controller, seq: [:b, :c, :g, :a, :f, :x, :d], terminus: our_controller.to_h[:outputs][:success].signal
    end
  end

  it "adds {subprocess: true} to normalizer ctx" do
    my_activity = Class.new(Trailblazer::Activity::Path) do
      step Subprocess(Trailblazer::Activity::Path),
        id: :a,
        Trailblazer::Activity::DSL::Feature::Data.Variable() => [:subprocess]
    end

    assert_equal my_activity.config.builder.sequence.nodes[:a].data[:subprocess], true
  end
end
