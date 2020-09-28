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
        step(id: :b, task: implementing.method(:b), before: :a)
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

    it "allows re-using the same method, with two different {:id}s" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:f)
        step implementing.method(:f), id: :f2
      end

      process = activity.to_h

      assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
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

      _(exception.message.sub(/0x\w+/, "0x")).must_equal %{ID #<Method: #<Module:0x>.f> is already taken. Please specify an `:id`.}
    end

    it "accepts {:outputs}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        # step MyMacro()
        step(id: :b, task: implementing.method(:b), before: :a, outputs: {success: Activity.Output("Yo", :success)})
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

    it ":override with inheritance" do
      activity = Class.new(Activity::Railway) do
        step :a#, id: :a
      end

      sub = Class.new(activity) do
        step :a, override: true#, id: :a
      end

      assert_process_for sub.to_h, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
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
        step(id: :b, task: implementing.method(:b), before: :a, Output(:success) => End(:new))
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
      implementing = T.def_steps(:a, :c, :b)

      activity = Class.new(Activity::Railway) do
        step implementing.method(:a), Output(:failure) => End(:new)
        step implementing.method(:c)
        step implementing.method(:b), Output(:success) => End(:new)
      end

      assert_process_for activity.to_h, :success, :new, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => #<End/:new>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:new>
#<End/:success>

#<End/:new>

#<End/:failure>
}

      signal, (ctx, _) = activity.([{seq: [], a: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:new>}
      _(ctx.inspect).must_equal     %{{:seq=>[:a], :a=>false}}

      new_signal, (ctx, _) = activity.([{seq: [], b: true}])

      _(new_signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:new>}
      _(ctx.inspect).must_equal %{{:seq=>[:a, :c, :b], :b=>true}}
  # End.new is always the same instance
      _(signal).must_equal new_signal

    end

    it "accepts {Output() => Id()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step(id: :b, task: implementing.method(:b), Output(:success) => Id(:a))
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
        step(id: :b, task: implementing.method(:b), Output(:success) => Track(:unknown))
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
        step(id: :b, task: implementing.method(:b),
          Output(Activity::Left, :success) => Track(:success),
          Output("Signalovich", :new)      => Id(:a))
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
        step(id: :b, task: implementing.method(:b), connections: {success: [Linear::Search.method(:ById), :a]})
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

        step(id: :b, task: implementing.method(:b), adds: [
          {
            row:    row,
            insert: [Linear::Insert.method(:Prepend), :a]
          }
        ])
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

    describe "{:extensions}" do
      let(:merge) do
        merge = [
          [Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
        ]
      end

      it "accepts {:extensions}" do
        implementing = self.implementing

        merge = self.merge

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

        _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        _(ctx.inspect).must_equal %{{:seq=>[1, :a, :b]}}
      end

      it "accepts {:extensions} along with {:input}" do
        implementing = self.implementing

        merge = self.merge

        activity = Class.new(Activity::Path) do
          # :extensions doesn't overwrite :input and vice-versa!
          step implementing.method(:a), id: :a, extensions: [Trailblazer::Activity::TaskWrap::Extension(merge: merge)], input: ->(ctx, *) { {seq: ctx[:seq] += [:input]} }
          step implementing.method(:b), id: :b
        end

        signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}])

        _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        _(ctx.inspect).must_equal %{{:seq=>[1, :input, :a, :b]}}
      end

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



    _(activity.to_h[:nodes][1][:data].inspect).must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :id=>:f, :dsl_track=>:step}}
    _(activity.to_h[:nodes][2][:data].inspect).must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :id=>:c, :dsl_track=>:pass}}
    _(activity.to_h[:nodes][3][:data].inspect).must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure]}, :id=>:b, :dsl_track=>:fail}}
  end

# Sequence insert
  it "throws {Sequence::IndexError} exception when {:after} references non-existant {:id}" do
    exc = assert_raises Activity::DSL::Linear::Sequence::IndexError do
      class Song < Activity::Railway
        step :f, after: :e
        include T.def_steps(:f)
      end
    end

    _(exc.step_id).must_equal :e
    _(exc.message).must_equal %{#{Song}:
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

  it "inheritance copies {config}" do
    merge = [
      [taskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
    ]

    ext = taskWrap::Extension(merge: merge)

    activity = Class.new(Activity::Path) do
      step :a, extensions: [ext]
      include T.def_steps(:a)
    end

    sub = Class.new(activity)

  # {Schema.config} is *copied* to the subclass and not identical
    refute_equal activity.to_h[:config], sub.to_h[:config]
  # Likewise, important fields like {wrap_static} are copied.
    refute_equal activity.to_h[:config][:wrap_static], sub.to_h[:config][:wrap_static]

    signal, (ctx, _) = Activity::TaskWrap.invoke(activity, [{seq: []}, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[1, :a]}}

    signal, (ctx, _) = Activity::TaskWrap.invoke(sub, [{seq: []}, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[1, :a]}}
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

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[:a, :b]}}

    signal, (ctx, _) = Activity::TaskWrap.invoke(sub_activity, [{seq: []}, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[:a, :b, :f]}}
  end

  it "{:inherit} copies over additional user settings like {Output => Track}" do
      nested = Class.new(Activity::Path) do
        step :c_c

        include T.def_steps(:c_c)
      end

      sub_nested = Class.new(Activity::Path) do
      end

      class NestedWithThreeTermini < Activity::Railway
        step :x, Output(:success) => End(:legit)
        include T.def_steps(:x)

        class Sub < Activity::Railway
          step :z, Output(:success) => End(:legit)
          include T.def_steps(:z)
        end
      end

      activity = Class.new(Activity::Railway) do
        step Subprocess(nested), id: :c,
          Output(:failure) => Id(:b) # this must be inherited to {sub}!

        step Subprocess(NestedWithThreeTermini), id: :d,
          Output(:legit) => Id(:b) # this must be inherited to {sub}!

        step :a, Output(:failure) => Track(:success)
        step :b, Output("Bla", :bla) => Track(:failure)

        include T.def_steps(:b)
      end

      sub = Class.new(activity) do
        # TODO: what if we want to inherit outputs AND provide wirings?
        step Subprocess(sub_nested), inherit: true, id: :c, replace: :c, Output(:yo, :bla)=>Track(:success) # DISCUSS: inherit is a replace, isn't it?
        step :a, inherit: true, id: :a, replace: :a
        # step :b, inherit: true, id: :b, replace: :b
      end

      # the nested's output must be the signal from the sub_nested's terminus
      _(Trailblazer::Activity::Introspect::Graph(sub).find(:c).outputs[1].to_h[:signal]).must_equal sub_nested.to_h[:outputs][0].to_h[:signal]

      assert_process_for sub.to_h, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {Trailblazer::Activity::Left} => <*b>
 {#<Trailblazer::Activity::End semantic=:success>} => ActivityTest::NestedWithThreeTermini
 {yo} => ActivityTest::NestedWithThreeTermini
ActivityTest::NestedWithThreeTermini
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*a>
 {#<Trailblazer::Activity::End semantic=:legit>} => <*b>
<*a>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Bla} => #<End/:failure>
#<End/:success>

#<End/:failure>
}


    # we want to replace {NestedWithTreeTermini} (step :d) but inherit the {End.legit => :b} wiring.
    sub = Class.new(activity) do
      step Subprocess(NestedWithThreeTermini::Sub), inherit: true, id: :d, replace: :d
    end

    ctx = {seq: []}
    signal, (ctx, _) = Trailblazer::Developer.wtf?(sub, [ctx])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx[:seq].inspect).must_equal %{[:c_c, :z, :b]}

    ctx = {seq: [], z: false}
    signal, (ctx, _) = Trailblazer::Developer.wtf?(sub, [ctx])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    _(ctx[:seq].inspect).must_equal %{[:c_c, :z]}
  end

  it "{:inherit} also adds the {:extensions} from the inherited row" do
    merge = [
      [taskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
    ]

    ext = taskWrap::Extension(merge: merge)

    activity = Class.new(Activity::Path) do
      step :a, extensions: [ext]
      step :b # no {:extensions}

      include T.def_steps(:a, :b)
    end

    sub = Class.new(activity) do
      step :a, inherit: true, id: :a, replace: :a # this should also "inherit" the taskWrap configs for this task.

      step :b, inherit: true, id: :b, replace: :b, extensions: [ext] # we want to "override" the original {:extensions}
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[1, :a, :b]}}

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(sub, [{seq: []}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[1, :a, 1, :b]}}
  end

  it "assigns default {:id}" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step implementing.method(:a), id: :a
      step implementing.method(:b)
    end

    _(activity.to_h[:nodes].collect(&:id)).must_equal ["Start.default", :a, implementing.method(:b), "End.success"]
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
        signal, (ctx, _) = activity.([{seq: []}])

        _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
        _(ctx.inspect).must_equal     %{{:seq=>[:a, :b, :c]}}

  # a --> Nested(b) --> :failure
        signal, (ctx, _) = activity.([{seq: [], b: false}])

        _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
        _(ctx.inspect).must_equal     %{{:seq=>[:a, :b], :b=>false}}
      end

      scenario "manual wiring with Subprocess()" do
        activity = Class.new(Activity::Railway) do
          step implementing.method(:a)
          step Subprocess(nested), Output(:success) => Track(:failure)
          step implementing.method(:c)
        end

        test "Nested's :success End is mapped to outer :failure" do
          signal, (ctx, _) = activity.([{seq: []}])

          _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
          _(ctx.inspect).must_equal     %{{:seq=>[:a, :b]}}
        end

        test "Nested's :failure goes to outer :failure per default" do
          signal, (ctx, _) = activity.([{seq: [], b: false}])

          _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
          _(ctx.inspect).must_equal     %{{:seq=>[:a, :b], :b=>false}}
        end
      end
    end
  end

  describe "Path()" do
    it "allows referencing the activity classes' methods in the {Path} block" do
      activity = Class.new(Activity::Path) do
        extend T.def_tasks(:a, :b, :c)

        out = self
        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do
          step out.method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h

    assert_process_for process, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.a>>
<*#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.c>>
<*#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
<*#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:path>
}
    end

    it "allows customized options" do
      shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}
      # state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(**shared_options))

      activity = Class.new(Activity::Path(shared_options)) do
        extend T.def_steps(:a, :b, :c)

        path = self
        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do
          step path.method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h

      assert_process_for process, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:path>
}
    end
  end

  it "provides {DSL} instance that doesn't compile the activity" do
    path = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())

    implementing = self.implementing
    # The DSL::Instance instance is the only mutable object.
    path.instance_exec do
      step implementing.method(:c), Activity::Path.Output("New", :new) => Activity::Path.End(:new)
      step implementing.method(:d)
    end

    sequence = path.to_h[:sequence]

    schema = Activity::DSL::Linear::Compiler.(sequence)

    assert_process_for schema, :success, :new, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
 {New} => #<End/:new>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:new>
}
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

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:a, :c, :d, :b]}}
  end

  it "allows instance methods with circuit interface" do
    implementing = self.implementing

    nested_activity = Class.new(Activity::Path) do
      step task: :c
      step task: :d
      include T.def_tasks(:c, :d)
    end

    activity = Class.new(Activity::Path) do
      step task: :a
      step Subprocess(nested_activity)
      step task: :b
      include T.def_tasks(:a, :b)
    end

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:a, :c, :d, :b]}}
  end

  it "assigns {:task} as step's {:id} unless specified" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step task: :a
      step task: :b, id: :b
      step task: implementing.method(:c)
      step task: implementing.method(:d), id: :d
      step({ task: implementing.method(:f), id: :f }, replace: implementing.method(:c))

      include T.def_tasks(:a, :b)
    end

    _(Trailblazer::Developer.railway(activity)).must_equal %{[>a,>b,>f,>d]}

    signal, (ctx, _) = activity.([{seq: []}])
    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:a, :b, :f, :d]}}
  end

  it "provides {#to_h}" do
    activity = Class.new(Activity::Path) do
      step :a
    end

    actual_activity = activity.instance_variable_get(:@activity)
    _(actual_activity.class).must_equal Trailblazer::Activity
    _(activity.to_h[:activity]).must_equal actual_activity
  end

  it "{Path()} without block just adds one {End.green} terminus" do
    activity = Class.new(Activity::Railway) do
      step :a, Output(:success) => Track(:green)
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc), track_color: :green) do
      end

      # step :d, Output(:failure) => Track(:green, wrap_around: true)

      include T.def_steps(:c, :d)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

  end
  it "{Path()} allows connecting an earlier step {:a} to the beginning of the path." do
    activity = Class.new(Activity::Railway) do
      step :a, Output(:failure) => Track(:green) # look for the first {magnetic_to: :green} occurrence.
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc), track_color: :green) do
        step :d
      end

      include T.def_steps(:c, :d)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => <*d>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

  end

  it "{Path()} allows connecting a later step {:f} to the end of the path." do
    activity = Class.new(Activity::Railway) do
      step :a, Output(:failure) => Track(:green)
      step :c, Output(:success) => Path(track_color: :green) do
        step :d  # look for the next {magnetic_to: :green} occurrence.
      end
      step :e
      step :f, magnetic_to: :green

      include T.def_steps(:c, :d, :e, :f)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => <*d>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => <*f>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "{Path()} allows connecting to the outer step using {Output() => Id()}" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path() do
        step :d, Output(:success) => Id(:f)
        step :e
      end
      step :f

      include T.def_steps(:c, :d, :e, :f)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => <*f>
<*e>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:c, :d, :f]}}
  end

  it "{Path()} allows emitting signal via {End()}" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path() do
        step :e
        step :d, Output(:success) => End(:without_cc)
      end
      step :f

      include T.def_steps(:c, :e, :d, :f)
    end

    assert_process_for activity, :success, :without_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:without_cc>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:without_cc>

#<End/:failure>
}

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:without_cc>}
    _(ctx.inspect).must_equal     %{{:seq=>[:c, :e, :d]}}
  end

  it "{Path()} allows nesting via {Subprocess()}" do
    nested = Class.new(Activity::Railway) do
      step :a
      step :b, Output(:success) => End(:charge)

      include T.def_steps(:a, :b)
    end

    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path() do
        step :e
        step Subprocess(nested), Output(:charge) => End(:with_cc)
        step :d
      end
      step :f

      include T.def_steps(:c, :e, :d, :f)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => <*d>
 {#<Trailblazer::Activity::End semantic=:charge>} => #<End/:with_cc>
<*d>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:with_cc>}
    _(ctx.inspect).must_equal     %{{:seq=>[:c, :e, :a, :b]}}
  end

  it "{Output()} takes precedence over {end_id} when specified within the {Path()} block" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc)) do
        step :e, Output(:success) => Id(:f) # `End(:with_cc)` will get removed in favor of `Id(:f) connection`
      end
      step :f

      include T.def_steps(:c, :e, :f)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:c, :e, :f]}}
  end

  it "{connect_to} behaves same as {Output() => Id()} connection when passed to the {Path()}" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(connect_to: Id(:f)) do
        step :e
      end
      step :f

      include T.def_steps(:c, :e, :f)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    signal, (ctx, _) = activity.([{seq: []}])

    _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal     %{{:seq=>[:c, :e, :f]}}
  end

  it "{:wrap_around}" do
    implementing = self.implementing

    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc), track_color: :green) do
      end

      # success:c, success=>green
      # green:End.green

    # we want to connect an Output to the {green} path.
    # The problem is, the path is positioned in the sequence.
      step :d, Output(:failure) => Track(:green, wrap_around: true)

      include T.def_steps(:c, :d)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
<*d>
 {Trailblazer::Activity::Left} => #<End/:with_cc>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

  # WrapAround does wrap around, but considers track colors before it wraps.
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc), track_color: :green) do
      end

      step :d, Output(:failure) => Track(:green, wrap_around: true) # the option doesn't kick in.

      step :e, magnetic_to: :green # please connect {d} to {e}! and {c} to {e}
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*d>
 {Trailblazer::Activity::Left} => <*e>
 {Trailblazer::Activity::Right} => #<End/:success>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}
  end


  # inheritance
  # macaroni
  # Path() with macaroni
  # merge!
  # :step_method
  # :extension API/state for taskWrap, also in Path()
end
