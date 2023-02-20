require "test_helper"

class FastTrackTest < Minitest::Spec
  describe "Activity.FastTrack() builder" do
    it "allows to define custom End instances" do
      MyFailure  = Class.new(Activity::End)
      MySuccess  = Class.new(Activity::End)
      MyPassFast = Class.new(Activity::End)
      MyFailFast = Class.new(Activity::End)

      activity = Activity::FastTrack(
          end_task: MySuccess.new(semantic: :my_success),
          failure_end: MyFailure.new(semantic: :my_failure),
          fail_fast_end: MyFailFast.new(semantic: :fail_fast),
          pass_fast_end: MyPassFast.new(semantic: :pass_fast),
        ) do

        step task: T.def_task(:a)
      end

      _(activity.to_h[:outputs].inspect).must_equal %{[#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MySuccess semantic=:my_success>, semantic=:my_success>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyPassFast semantic=:pass_fast>, semantic=:pass_fast>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailFast semantic=:fail_fast>, semantic=:fail_fast>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailure semantic=:my_failure>, semantic=:my_failure>]}

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<FastTrackTest::MyFailure/:my_failure>
 {Trailblazer::Activity::Right} => #<FastTrackTest::MySuccess/:my_success>
#<FastTrackTest::MySuccess/:my_success>

#<FastTrackTest::MyPassFast/:pass_fast>

#<FastTrackTest::MyFailFast/:fail_fast>

#<FastTrackTest::MyFailure/:my_failure>
}
    end

    # @generic strategy test
    it "copies (extended) normalizers from original {Activity::FastTrack} and thereby allows i/o" do
      path = Activity.FastTrack() do
        step :model, Inject() => {:id => ->(*) { 1 }}

        def model(ctx, id:, seq:, **)
          seq << id
        end
      end

      assert_invoke path, seq: %{[1]}
    end
  end

  describe "Activity::FastTrack" do

    it "provides defaults" do
      implementing = T.def_steps(:f, :a, :g, :c, :b, :d)

      activity = Class.new(Activity::FastTrack) do
        step implementing.method(:f), id: :f
        fail implementing.method(:a), id: :a
        step implementing.method(:g), id: :g
        step implementing.method(:c), id: :c, fast_track: true
        fail implementing.method(:b), id: :b
        pass implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a, :b], :f=>false}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :b], :g=>false}}

  # c --> pass_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Trailblazer::Activity::FastTrack::PassFast}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c], :c=>Trailblazer::Activity::FastTrack::PassFast}}

  # c --> fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Trailblazer::Activity::FastTrack::FailFast}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c], :c=>Trailblazer::Activity::FastTrack::FailFast}}

    end

    it "{#fail} with {fail_fast: true}" do
      activity = Class.new(Activity::FastTrack) do
        fail :errors, fail_fast: true
      end

      assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
<*errors>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    end

    it "provides {:pass_fast} and {:fail_fast}" do
      implementing = T.def_steps(:f, :a, :g, :c, :b, :d)

      activity = Class.new(Activity::FastTrack) do
        step implementing.method(:f), id: :f
        fail implementing.method(:a), id: :a, fail_fast: true
        step implementing.method(:g), id: :g, pass_fast: true, fail_fast: true
        fail implementing.method(:b), id: :b
        step implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

  # g --> :pass_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g]}}

  # a --> :fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a], :f=>false}}

  # a --> :fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false, a: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a], :f=>false, :a=>false}}

  # g --> :fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g], :g=>false}}
    end

    it "{:pass_fast} and {:fail_fast} DSL options also registers their own termini" do
      implementing = T.def_tasks(:a, :b, :c, :d, :e, :f)

      sub_nested = Class.new(Activity::FastTrack) do
        step task: implementing.method(:a), id: :a, Output(:failure) => End(:fail_fast)
        step task: implementing.method(:b), id: :b
      end

      nested = Class.new(Activity::FastTrack) do
        step Subprocess(sub_nested), fail_fast: true
        step task: implementing.method(:c), id: :c, Output(:success) => End(:pass_fast)
        step task: implementing.method(:d), id: :d
      end

      activity = Class.new(Activity::FastTrack) do
        step Subprocess(nested), fail_fast: true, pass_fast: true
        fail implementing.method(:e), id: :e
        step implementing.method(:f), id: :f
      end

      process = activity.to_h

      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

  # nested --> :pass_fast
      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:a, :b, :c]}}

      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], a: Activity::Left }])

  # a --> :fail_fast
      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      _(ctx.inspect).must_equal     %{{:seq=>[:a], :a=>Trailblazer::Activity::Left}}
    end

    it "fails when parent activity has not registered for any fast tracks but nested activity emits it" do
      implementing = T.def_tasks(:a, :b, :c, :d)

      nested = Class.new(Activity::FastTrack) do
        step task: implementing.method(:a), id: :a, Output(:failure) => End(:fail_fast)
        step task: implementing.method(:b), id: :b
      end

      activity = Class.new(Activity::FastTrack) do
        step Subprocess(nested)
        step task: implementing.method(:c), id: :c, Output(:success) => End(:pass_fast)
      end

      exception = assert_raises Trailblazer::Activity::Circuit::IllegalSignalError do
        activity.([{seq: [], a: Activity::Left }])
      end

      _(exception.message).must_include "Unrecognized Signal `#<Trailblazer::Activity::End semantic=:fail_fast>` returned from #{nested}"
    end

    it "{#pass} with {:pass_fast}" do
      implementing = T.def_steps(:f, :a, :g, :c, :b, :d)

      activity = Class.new(Activity::FastTrack) do
        pass implementing.method(:f), pass_fast: true
        fail implementing.method(:a), fail_fast: true
        step implementing.method(:d)
        fail implementing.method(:g)
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Left} => #<End/:pass_fast>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Right} => #<End/:success>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

  # f --> Right --> :pass_fast
        signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

        _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
        _(ctx.inspect).must_equal     %{{:seq=>[:f]}}

  # f --> Left --> :pass_fast
        signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

        _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
        _(ctx.inspect).must_equal     %{{:seq=>[:f], :f=>false}}

    end
  end

  it "accepts {:termini} and overrides FastTrack's termini" do
      path = Activity.FastTrack(
        termini: [
                  [Activity::End.new(semantic: :success), id: "End.success",  magnetic_to: :success, append_to: "Start.default"],
                  [Activity::End.new(semantic: :winning), id: "End.winner",   magnetic_to: :winner],
                  [Activity::End.new(semantic: :pass_fast), id: "End.pass_fast",   magnetic_to: :pass_fast],
                ]
      ) do
        step :f
        step :g, Output(Object, :failure) => Track(:winner), pass_fast: true, fast_track: true
      end

# FIXME: f/failure shouldn't go to End.winner
      assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:winning>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Object} => #<End/:winning>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:winning>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
#<End/:success>

#<End/:pass_fast>

#<End/:winning>
}
  end

  it "{fast_track: true} respects returned {FailFast} and {PassFast} signals from the step" do
    activity = Class.new(Activity::FastTrack) do
      step :validate, fast_track: true

      def validate(ctx, fast:, railway_boolean: nil, **)
        return railway_boolean unless railway_boolean.nil?
        fast ? Activity::FastTrack::PassFast : Activity::FastTrack::FailFast
      end
    end

    assert_invoke activity, railway_boolean: true, fast: nil, terminus: :success
    assert_invoke activity, railway_boolean: false, fast: nil, terminus: :failure
    assert_invoke activity, fast: true, terminus: :pass_fast
    assert_invoke activity, fast: false, terminus: :fail_fast
  end

  it "without {fast_track: true} there is {Output(:pass_fast)} for Subprocess, only" do
    activity = Class.new(Activity::FastTrack) do
      step Subprocess(Activity::FastTrack), Output(:pass_fast) => Track(:success)
    end

    assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => Trailblazer::Activity::FastTrack
Trailblazer::Activity::FastTrack
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
  end

  it "without {fast_track: true} there is no {Output(:pass_fast)} for scalar task" do
    exception = assert_raises do
      activity = Class.new(Activity::FastTrack) do
        step :model, Output(:pass_fast) => Track(:success)
      end
    end

    assert_equal exception.message, %{No `pass_fast` output found for :model and outputs {:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}}
  end
end
