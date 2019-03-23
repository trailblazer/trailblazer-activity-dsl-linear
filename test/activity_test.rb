require "test_helper"

# macro Output => End
# Output(NewSignal, :semantic)

class ActivityTest < Minitest::Spec
  describe "macro" do

    it "accepts {:before} in macro options" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        # step MyMacro()
        step({id: :b, task: implementing.method(:b), before: :a})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {:outputs}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        # step MyMacro()
        step({id: :b, task: implementing.method(:b), before: :a, outputs: {success: Activity.Output("Yo", :success)}})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Yo} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {:override}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step implementing.method(:a), id: :a
        step implementing.method(:b), id: :b
        step(
          {id: :a, task: implementing.method(:c)}, # macro
          override: true
        )
      end

      assert_process_for activity.to_h, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    end

    it "allows setting a custom, new end" do
      implementing = self.implementing

      new_end = Activity::End(:new)

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a

        step task: new_end, id: :new_end,
          # by providing {:stop_event} and {:outputs} options, we can create an End.
          stop_event: true,
          outputs:    {success: Activity::Output.new(new_end, new_end.to_h[:semantic])}

        step implementing.method(:b), id: :b, magnetic_to: nil
      end

      assert_process_for activity.to_h, :new, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:new>
#<End/:new>

<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {Output() => End()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), before: :a, Output(:success) => End(:new)})
      end

      assert_process_for activity.to_h, :success, :new, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:new>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:new>
}
    end

    it "doesn't create the same End twice" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step implementing.method(:a), Output(:failure) => End(:new)
        step implementing.method(:c)
        step implementing.method(:b), Output(:failure) => End(:new)
      end

      assert_process_for activity.to_h, :success, :new, :failure, %{
      }
    end

    it "accepts {Output() => Id()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), Output(:success) => Id(:a)})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}
    end

    it "allows {Output() => Track(:unknown)} and connects unknown to Start.default" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), Output(:success) => Track(:unknown)})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
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
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b),
          Output(Activity::Left, :success) => Track(:success),
          Output("Signalovich", :new)      => Id(:a)})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Signalovich} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}
    end

    it "accepts {:connections}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), connections: {success: [Linear::Search.method(:ById), :a]}})
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}
    end

    it "accepts {:adds}" do
      implementing = self.implementing

      circuit_interface_tasks = T.def_tasks(:c)

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a

        row = Linear::Sequence.create_row(task: circuit_interface_tasks.method(:c), id: :c, magnetic_to: :success,
            wirings: [Linear::Search::Forward(Activity.Output(Activity::Right, :success), :success)])

        step({id: :b, task: implementing.method(:b), adds: [
          {
            row:    row,
            insert: [Linear::Insert.method(:Prepend), :a]
          }
        ]
        })
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
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

    it "accepts {:extensions}" do
      implementing = self.implementing

      merge = [
        [Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      ]

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a, extensions: [Trailblazer::Activity::TaskWrap::Extension(merge: merge)]
        step implementing.method(:b), id: :b
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}])

      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:seq=>[1, :a, :b]}}
    end
  end

  it "accepts {:magnetic_to}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a, Output(:success) => Track(:new), Output(false, :failure) => Track(:success)
        step implementing.method(:b), magnetic_to: :new
      end

      assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
 {false} => #<End/:success>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

# Introspect
  it "provides additional {:data} for introspection" do
    implementing = self.implementing

    activity = Class.new(Activity::Railway) do
      step task: implementing.method(:f), id: :f
      pass task: implementing.method(:c), id: :c
      fail task: implementing.method(:b), id: :b
    end

    activity.to_h[:nodes][1][:data].inspect.must_equal %{{:id=>:f, :dsl_track=>:step}}
    activity.to_h[:nodes][2][:data].inspect.must_equal %{{:id=>:c, :dsl_track=>:pass}}
    activity.to_h[:nodes][3][:data].inspect.must_equal %{{:id=>:b, :dsl_track=>:fail}}
  end

# Sequence insert
  it "throws an IndexError exception when {:after} references non-existant" do
    implementing = self.implementing

    exc = assert_raises Activity::DSL::Linear::Sequence::IndexError do
      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), after: :e
      end
    end

    exc.inspect.must_equal %{#<Trailblazer::Activity::DSL::Linear::Sequence::IndexError: :e>}
  end

  it "allows empty inheritance" do
    activity = Class.new(Activity::Path)

    assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "allows inheritance / INSERTION options" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step implementing.method(:a), id: :a
      step implementing.method(:b), id: :b
    end

    copy = Class.new(activity)

    sub_activity = Class.new(activity) do
      step implementing.method(:c), id: :c
      step implementing.method(:d), id: :d
    end

    sub_sub_activity = Class.new(sub_activity) do
      step implementing.method(:g), id: :g, before: :b
      step implementing.method(:f), id: :f, replace: :a
      step nil,                             delete: :c
    end

    process = activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for copy.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "allows, when inheritance time, to inject normalizer options" do
    implementing = Module.new do
      extend Activity::Testing.def_steps(:a, :f, :b) # circuit interface.
    end

    activity = Class.new(Activity::Path(step_interface_builder: Fixtures.method(:circuit_interface_builder))) do
      step implementing.method(:a), id: :a
      step implementing.method(:b), id: :b
    end

    sub_activity = Class.new(activity) do
      step implementing.method(:f), id: :f
    end

    process = activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}


    signal, (ctx, _) = Activity::TaskWrap.invoke(activity, [{seq: []}, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a, :b]}}

    signal, (ctx, _) = Activity::TaskWrap.invoke(sub_activity, [{seq: []}, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a, :b, :f]}}
  end

  it "assigns default {:id}" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step implementing.method(:a), id: :a
      step implementing.method(:b)
    end

    activity.to_h[:nodes].collect(&:id).must_equal ["Start.default", :a, implementing.method(:b), "End.success"]
  end

  describe "#merge!" do
    it "what" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step implementing.method(:b), id: :b
      end

      sub_activity = Class.new(Activity::Path) do
        step implementing.method(:c), id: :c
        merge!(activity)
        step implementing.method(:d), id: :d
      end

      process = sub_activity.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end

  describe "#Subprocess" do
    def scenario(*, &block) # TODO: move to {organic}.
      yield
    end
    def test(*, &block)
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
        signal, (ctx, _) = activity.([{seq: []}])

        signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
        ctx.inspect.must_equal     %{{:seq=>[:a, :b, :c]}}

  # a --> Nested(b) --> :failure
        signal, (ctx, _) = activity.([{seq: [], b: false}])

        signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
        ctx.inspect.must_equal     %{{:seq=>[:a, :b], :b=>false}}
      end

      scenario "manual wiring with Subprocess()" do
        activity = Class.new(Activity::Railway) do
          step implementing.method(:a)
          step Subprocess(nested), Output(:success) => Track(:failure)
          step implementing.method(:c)
        end

        test "Nested's :success End is mapped to outer :failure" do
          signal, (ctx, _) = activity.([{seq: []}])

          signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
          ctx.inspect.must_equal     %{{:seq=>[:a, :b]}}
        end

        test "Nested's :failure goes to outer :failure per default" do
          signal, (ctx, _) = activity.([{seq: [], b: false}])

          signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
          ctx.inspect.must_equal     %{{:seq=>[:a, :b], :b=>false}}
        end
      end
    end
  end

  describe "Path()" do
    it "allows referencing the activity classes' methods in the {Path} block" do
      activity = Class.new(Activity::Path) do
        extend T.def_tasks(:a, :b, :c)

        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do |path|
          step method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h

    assert_process_for process, :path, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.a>>
<*#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.c>>
<*#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<End/:path>

<*#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "allows customized options" do
      shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}
      # state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(**shared_options))

      activity = Class.new(Activity::Path(shared_options)) do
        extend T.def_steps(:a, :b, :c)

        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do |path|
          path.step method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h

      assert_process_for process, :path, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<End/:path>

#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end




  # inheritance
  # macaroni
  # Path() with macaroni
  # merge!
  # :step_method
  # :extension API/state for taskWrap, also in Path()
end
