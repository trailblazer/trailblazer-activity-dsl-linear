require "test_helper"

# macro Output => End
# Output(NewSignal, :semantic)

class ActivityTest < Minitest::Spec
  let(:Activity) { Trailblazer::Activity }

  describe "macro" do

    it "accepts {:before} in macro options" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        # step MyMacro()
        step id: :b, task: implementing.method(:b), before: :a
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "allows re-using the same method, with two different {:id}s" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :f
        step :f, id: :f2
      end

      process = activity.to_h

      assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "allows re-using the same activity, with two different {:id}s" do
      nested = Class.new(Activity::Path) do
        step :c_c

        include T.def_steps(:c_c)
      end

      activity = Class.new(Activity::Path) do
        step Subprocess(nested)
        step Subprocess(nested), id: :nesting_again
      end

      process = activity.to_h

      assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>
}
    end

    it "raises re-using the same method" do
      implementing = self.implementing

      exception = assert_raises do
        activity = Class.new(Activity::Path) do
          step implementing.method(:f)
          step implementing.method(:f)
        end
      end

      exception.message.must_equal %{ID #{implementing.method(:f).inspect} is already taken. Please specify an `:id`.}
    end

    it "raises re-using the same circuit task" do
      exception = assert_raises do
        Class.new(Activity::Path) do
          extend T.def_tasks(:f)

          step task: :f
          step task: :f
        end
      end

      exception.message.must_equal %{ID f is already taken. Please specify an `:id`.}
    end

    it "accepts {:outputs}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        # step MyMacro()
        step :b, before: :a, outputs: {success: Activity.Output("Yo", :success)}
      end

      assert_process_for activity, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Yo} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

# FIXME: wiring api tests/output tuples
    it "accepts {Output() => End()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        step :b, before: :a, Output(:success) => End(:new)
      end

      assert_process activity, :success, :new, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:new>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:new>
}
    end

    it "doesn't create the same End twice" do
      activity = Class.new(Activity::Railway) do
        step :a, Output(:failure) => End(:new)
        step :c
        step :b, Output(:success) => End(:new)

        include T.def_steps(:a, :c, :b)
      end

      assert_process activity, :success, :new, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:new>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:new>
#<End/:success>

#<End/:failure>

#<End/:new>
}

      assert_invoke activity, seq: "[:a]", a: false, terminus: :new
      assert_invoke activity, seq: "[:a, :c, :b]", b: true, terminus: :new
    end

    it "accepts {Output() => Id()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        step :b, Output(:success) => Id(:a)
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => <*a>
#<End/:success>
}
    end

    it "allows {Output() => Track(:unknown)} and connects unknown to Start.default" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        step :b, Output(:success) => Track(:unknown)
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "provides incomplete circuit when referencing non-existant task" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c, Output(:failure) => Id(:idontexist)
        step task: implementing.method(:b), id: :b
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    end

    it "accepts {Output() => Track()}"

    it "accepts {Output(Signal, :semantic) => Track()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        step :b,
          Output(Activity::Left, :success) => Track(:success),
          Output("Signalovich", :new)      => Id(:a)
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Signalovich} => <*a>
#<End/:success>
}
    end

    it "accepts {:adds}" do
      implementing = self.implementing

      circuit_interface_tasks = T.def_tasks(:c)

      activity = Class.new(Activity::Path) do
        step :a

        row = Trailblazer::Activity::DSL::Linear::Sequence.Row(
          task: circuit_interface_tasks.method(:c),
          data: {id: :c},
          magnetic_to: :success,
          wirings: {Activity.Output(Activity::Right, :success) => Activity::DSL::Linear::Sequence::Search::Forward.new(:success)},
          task_wrap: Activity::TaskWrap::INITIAL_TASK_WRAP,
        )

        step(id: :b, task: implementing.method(:b), adds: [
          [
            row,
            prepend: :a,
            id: nil
          ]
        ])
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    def add_1(wrap_ctx, original_args)
      ctx, _ = original_args[0]
      ctx[:seq] << 1
      return wrap_ctx, original_args # yay to mutable state. not.
    end
  end

  it "accepts {:magnetic_to}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a, Output(:success) => Track(:new), Output(false, :failure) => Track(:success)
        step :b, magnetic_to: :new
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
 {false} => #<End/:success>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

# Sequence insert
  it "throws {Sequence::IndexError} exception when {:after} references non-existant {:id}" do
    exc = assert_raises Activity::Adds::IndexError do
      class Song < Activity::Railway
        step :f, after: :e
        include T.def_steps(:f)
      end
    end

    assert_equal exc.message, %{#{Song}:
\e[31m:e is not a valid step ID. Did you mean any of these ?\e[0m
\e[32m"Start.default"\n"End.success"\n"End.failure"\e[0m}
  end

  it "allows empty inheritance" do
    activity = Class.new(Activity::Path)

    assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  let(:taskWrap) { Trailblazer::Activity::TaskWrap }

  #@ When inheriting and changing we don't bleed into associated classes.
  it "inheritance copies {config}" do
    ext = taskWrap::Extension(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
    )

    activity = Class.new(Activity::Path) do
      step :a, Extension() => ext
      include T.def_steps(:a)
    end

    sub = Class.new(activity)

  # {Schema.config} is not *copied* to the subclass identical.
    assert_equal activity.to_h[:config], sub.to_h[:config]
  # Likewise, important fields like {wrap_static} are copied.
    assert_equal activity.to_h[:config][:wrap_static], sub.to_h[:config][:wrap_static]

    ctx, _, signal = Activity::TaskWrap.invoke(activity, {seq: []}, {})
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    CU.inspect(ctx).must_equal %{{:seq=>[1, :a]}}

    ctx, _, signal = Activity::TaskWrap.invoke(sub, {seq: []}, {})
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    CU.inspect(ctx).must_equal %{{:seq=>[1, :a]}}

  #@ When changing subclass, superclass doesn't change

    sub.step :a, extensions: [], replace: :a

    #= values in {config} are different now.
    refute_equal activity.to_h[:config], sub.to_h[:config]
    refute_equal activity.to_h[:config][:wrap_static], sub.to_h[:config][:wrap_static]

    puts activity.to_h[:config][:wrap_static]
    puts sub.to_h[:config][:wrap_static]
  end

  it "allows inheritance / INSERTION options" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step :a
      step :b
    end

    copy = Class.new(activity)

    sub_activity = Class.new(activity) do
      step :c
      step :d
    end

    sub_sub_activity = Class.new(sub_activity) do
      step :g, before: :b
      step :f, replace: :a
      step nil, delete: :c
    end

    process = activity.to_h
# raise process.inspect
    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for copy.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "allows, when inheritance time, to inject normalizer options" do
    implementing = Module.new do
      extend T.def_steps(:a, :f, :b) # circuit interface.
    end

    activity = Class.new(Activity::Path(step_interface_builder: Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface)) do
      step :a
      step :b

      include T.def_tasks(:a, :b)
    end

    sub_activity = Class.new(activity) do
      step :f

      include T.def_tasks(:f)
    end

    process = activity.to_h

    assert_process_for activity, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:f>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}


    assert_invoke activity, seq: "[:a, :b]"
    assert_invoke sub_activity, seq: "[:a, :b, :f]"
  end

  describe "#merge!" do
    it "what" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step :a
        step :b
      end

      sub_activity = Class.new(Activity::Path) do
        step :c
        merge!(activity)
        step :d
      end

      merge_is_last_activity = Class.new(Activity::Path) do
        step :c
        merge!(activity)
      end

      process = sub_activity
      assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

      assert_process_for merge_is_last_activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end

  describe "#Subprocess" do
    def scenario(*) # TODO: move to {organic}.
      yield
    end
    def test(*)
      yield
    end

    # scenario
    it "automatically provides {:outputs}" do
      implementing = T.def_steps(:a, :b, :c)

      nested = Class.new(Activity::Railway) do
        step implementing.method(:b)
      end

      activity = Class.new(Activity::Railway) do
        step implementing.method(:a)
        step Subprocess(nested)
        step implementing.method(:c)
      end

      scenario "automatic wiring from Subprocess()" do
  # a --> Nested(b) --> c
        assert_invoke activity, seq: "[:a, :b, :c]"

  # a --> Nested(b) --> :failure
        assert_invoke activity, seq: "[:a, :b]",  b:  false, terminus: :failure
      end

      scenario "manual wiring with Subprocess()" do
        activity = Class.new(Activity::Railway) do
          step implementing.method(:a)
          step Subprocess(nested), Output(:success) => Track(:failure)
          step implementing.method(:c)
        end

        test "Nested's :success End is mapped to outer :failure" do
          assert_invoke activity, seq: "[:a, :b]", terminus: :failure
        end

        test "Nested's :failure goes to outer :failure per default" do
          assert_invoke activity, seq: "[:a, :b]", b: false, terminus: :failure
        end
      end
    end
  end

  describe "Path()" do
    it "allows referencing the activity classes' methods in the {Path} block" do
      activity = Class.new(Activity::Path) do
        include T.def_tasks(:a, :b, :c)

        out = self
        step :a, Output(:success) => Path(terminus: :path) do
          step :c
        end
        step :b
      end

      process = activity.to_h

    assert_process_for process, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => #<End/:path>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:path>
}
    end

    it "allows customized options" do
      shared_options = {step_interface_builder: Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface}
      # state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(**shared_options))

      activity = Class.new(Activity::Path(**shared_options)) do
        include T.def_steps(:a, :b, :c)

        step :a, Output(:success) => Path(terminus: :path) do
          step :c
        end
        step :b
      end

      assert_process_for activity, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:a>>
 {Trailblazer::Activity::Right} => #<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:c>>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<struct Trailblazer::Activity::DSL::Linear::Normalizer::InstanceMethodWithCircuitInterface instance_method_option=#<Trailblazer::Activity::Option::InstanceMethod:0x @filter=:b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:path>
}
    end
  end

  it "allows {:instance} methods" do
    implementing = self.implementing

    nested_activity = Class.new(Activity::Path) do
      step :c
      step :d
      include T.def_steps(:c, :d)
    end

    activity = Class.new(Activity::Path) do
      step :a
      step Subprocess(nested_activity)
      step :b
      include T.def_steps(:a, :b)
    end

    assert_invoke activity, seq: "[:a, :c, :d, :b]"
  end
end
