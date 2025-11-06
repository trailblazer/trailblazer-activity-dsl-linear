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

        step task: T.def_tasks(:a).method(:a)
      end

      assert_equal CU.inspect(activity.to_h[:outputs]), %(\
[#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MySuccess semantic=:my_success>, semantic=:my_success>, \
#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailure semantic=:my_failure>, semantic=:my_failure>, \
#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyFailFast semantic=:fail_fast>, semantic=:fail_fast>, \
#<struct Trailblazer::Activity::Output signal=#<FastTrackTest::MyPassFast semantic=:pass_fast>, semantic=:pass_fast>])

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<FastTrackTest::MyFailure/:my_failure>
 {Trailblazer::Activity::Right} => #<FastTrackTest::MySuccess/:my_success>
#<FastTrackTest::MySuccess/:my_success>

#<FastTrackTest::MyFailure/:my_failure>

#<FastTrackTest::MyFailFast/:fail_fast>

#<FastTrackTest::MyPassFast/:pass_fast>
}
    end

    # @generic strategy test
    it "copies (extended) normalizers from original {Activity::FastTrack} and thereby allows i/o" do
      path = Activity.FastTrack() do
        step :model, Inject(:id) => ->(*) { 1 }

        def model(ctx, id:, seq:, **)
          seq << id
        end
      end

      assert_invoke path, seq: %{[1]}
    end
  end

  it "#step, #fail and #pass do not add a {:failure} connection if no {:failure} output exists" do
    activity = Class.new(Activity::FastTrack) do
      step Subprocess(Class.new(Activity::Path))
      pass Subprocess(Class.new(Activity::Path))
      fail Subprocess(Class.new(Activity::Path))
    end

    assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}
  end

  describe "Activity::FastTrack" do

    it "provides defaults" do
      activity = Class.new(Activity::FastTrack) do
        include T.def_steps(:f, :a, :g, :c, :b, :d)

        step :f
        fail :a
        step :g
        step :c, fast_track: true
        fail :b
        pass :d
      end

      assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => <*a>
 {Trailblazer::Activity::Right} => <*g>
<*a>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*b>
<*g>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*d>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*d>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}

  # right track
      assert_call activity, seq: "[:f, :g, :c, :d]"

  # left track
      assert_call activity, terminus: :failure, seq: "[:f, :a, :b]", f: false

  # left track
      assert_call activity, terminus: :failure, seq: "[:f, :g, :b]", g: false

  # c --> pass_fast
      assert_call activity, terminus: :pass_fast, seq: "[:f, :g, :c]", c: Trailblazer::Activity::FastTrack::PassFast

  # c --> fail_fast
      assert_call activity, terminus: :fail_fast, seq: "[:f, :g, :c]", c: Trailblazer::Activity::FastTrack::FailFast
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

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}
    end

    it "provides {:pass_fast} and {:fail_fast}" do
      activity = Class.new(Activity::FastTrack) do
        include T.def_steps(:f, :a, :g, :c, :b, :d)

        step :f
        fail :a, fail_fast: true
        step :g, pass_fast: true, fail_fast: true
        fail :b
        step :d
      end

      assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => <*a>
 {Trailblazer::Activity::Right} => <*g>
<*a>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
<*g>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}

  # g --> :pass_fast
      assert_call activity, terminus: :pass_fast, seq: "[:f, :g]"

  # a --> :fail_fast
      assert_call activity, terminus: :fail_fast, seq: "[:f, :a]", f: false

  # a --> :fail_fast
      assert_call activity, terminus: :fail_fast, seq: "[:f, :a]", f: false, a: false

  # g --> :fail_fast
      assert_call activity, terminus: :fail_fast, seq: "[:f, :g]", g: false
    end

    it "{:pass_fast} and {:fail_fast} DSL options also registers their own termini" do
      sub_nested = Class.new(Activity::FastTrack) do
        include T.def_steps(:a, :b)
        step :a, Output(:failure) => End(:fail_fast)
        step :b
      end

      nested = Class.new(Activity::FastTrack) do
        include T.def_steps(:c, :d)
        step Subprocess(sub_nested), fail_fast: true
        step :c, Output(:success) => End(:pass_fast)
        step :d
      end

      activity = Class.new(Activity::FastTrack) do
        include T.def_steps(:e, :f)
        step Subprocess(nested), fail_fast: true, pass_fast: true
        fail :e
        step :f
      end

  # nested --> :pass_fast
      assert_call activity, seq: "[:a, :b, :c]", terminus: :pass_fast

  # a --> :fail_fast
      assert_call activity, seq: "[:a]", terminus: :fail_fast, a: Trailblazer::Activity::Left
    end

    it "fails when parent activity has not registered for any fast tracks but nested activity emits it" do
      implementing = T.def_tasks(:a, :b, :c, :d)

      nested = Class.new(Activity::FastTrack) do
        include T.def_steps(:a, :b)
        step :a, Output(:failure) => End(:fail_fast)
        step :b
      end

      activity = Class.new(Activity::FastTrack) do
        step Subprocess(nested)
        step :c, Output(:success) => End(:pass_fast)
      end

      exception = assert_raises Trailblazer::Activity::Circuit::IllegalSignalError do
        activity.({seq: [], a: Activity::Left }, {}, {})
      end

      assert_includes exception.message, "Unrecognized signal `#<Trailblazer::Activity::End semantic=:fail_fast>` returned from #{nested}"
    end

    it "{#pass} with {:pass_fast}" do

      activity = Class.new(Activity::FastTrack) do
        include T.def_steps(:f, :a, :g, :c, :b, :d)

        pass :f, pass_fast: true
        fail :a, fail_fast: true
        step :d
        fail :g
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:pass_fast>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*a>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
<*d>
 {Trailblazer::Activity::Left} => <*g>
 {Trailblazer::Activity::Right} => #<End/:success>
<*g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}

  # f --> Right --> :pass_fast
      assert_call activity, terminus: :pass_fast, seq: "[:f]"

  # f --> Left --> :pass_fast
      assert_call activity, terminus: :pass_fast, seq: "[:f]", f: false
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

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
}
  end

  it "without {fast_track: true} there is no {Output(:pass_fast)} for scalar task" do
    exception = assert_raises do
      activity = Class.new(Activity::FastTrack) do
        step :model, Output(:pass_fast) => Track(:success)
      end
    end

    assert_equal CU.inspect(exception.message), %{No `pass_fast` output found for :model and outputs {:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}}
  end

  it "provides {left} alias for {fail}" do
    activity = Class.new(Activity::FastTrack) do
      step :f
      left :a
      include T.def_steps(:f, :a)
    end

    assert_circuit activity, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => <*a>
 {Trailblazer::Activity::Right} => #<End/:success>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/:fail_fast>

#<End/:pass_fast>
)

    # right track
    assert_call activity, seq: "[:f]"


    # f returns false
    assert_call activity, f: Activity::Left, seq: "[:f, :a]", terminus: :failure
  end
end
