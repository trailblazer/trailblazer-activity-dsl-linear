require "test_helper"

class FastTrackTest < Minitest::Spec
  it "#initial_sequence" do
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence(
        initial_sequence: Trailblazer::Activity::Railway::DSL.initial_sequence(
          initial_sequence: Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success"),
          failure_end: Activity::End.new(semantic: :failure)
        )
      )

      _(Cct(compile_process(seq))).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
  end

  describe "{:end_task}, {:failure_end}, {:fail_fast_end}, {:pass_fast_end}" do
    it "allows to define custom End instances" do
      MyFailure  = Class.new(Activity::End)
      MySuccess  = Class.new(Activity::End)
      MyPassFast = Class.new(Activity::End)
      MyFailFast = Class.new(Activity::End)

      activity = Class.new(Activity::FastTrack(
          end_task: MySuccess.new(semantic: :my_success),
          failure_end: MyFailure.new(semantic: :my_failure),
          fail_fast_end: MyFailFast.new(semantic: :fail_fast),
          pass_fast_end: MyPassFast.new(semantic: :pass_fast),
        )) do

        step task: T.def_task(:a)
      end

      _(activity.to_h[:outputs].inspect).must_equal %{[#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MySuccess semantic=:my_success>, semantic=:my_success>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyPassFast semantic=:pass_fast>, semantic=:pass_fast>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailFast semantic=:fail_fast>, semantic=:fail_fast>, #<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailure semantic=:my_failure>, semantic=:my_failure>]}

      assert_circuit activity.to_h, %{
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
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
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

    it "{:pass_fast} and {:fail_fast} DSL options also registers their own ends" do
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
end
