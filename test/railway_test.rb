require "test_helper"

class RailwayTest < Minitest::Spec
  it "#initial_sequence" do
    seq = Trailblazer::Activity::Railway::DSL.initial_sequence(
      # options for Railway
      failure_end: Class.new(Activity::End).new(semantic: :ready),
      # options going to Path.initial_sequence

      initial_sequence: Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success"),
    )

    _(Cct(compile_process(seq))).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<#<Class:0x>/:ready>
}
  end

  describe "Activity::Railway" do

    it "provides defaults" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
        step task: implementing.method(:c), id: :c
        fail task: implementing.method(:b), id: :b
        step task: implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a, :b], :f=>Trailblazer::Activity::Left}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :b], :g=>Trailblazer::Activity::Left}}
    end

    it "allows {Output() => Track/Id}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        fail task: implementing.method(:a), id: :a, Output(:success) => Track(:success)
        step task: implementing.method(:g), id: :g
        step task: implementing.method(:c), id: :c
        fail task: implementing.method(:b), id: :b
        step task: implementing.method(:d), id: :d, Output(:failure) => Id(:b)
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track, {a} goes back to success
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: Activity::Left, a: Activity::Right}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a, :g, :c, :d], :f=>Trailblazer::Activity::Left, :a=>Trailblazer::Activity::Right}}

  # left track, {a} stays on failure
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: Activity::Left, a: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :a, :b], :f=>Trailblazer::Activity::Left, :a=>Trailblazer::Activity::Left}}

  # {d} goes to {b}
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], d: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :g, :c, :d, :b], :d=>Trailblazer::Activity::Left}}
    end

    it "provides {pass}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c
        fail task: implementing.method(:a), id: :a
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c]}}

  # pass returns false
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c], :c=>Trailblazer::Activity::Left}}
    end

    it "provides {pass}, II" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c
        fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c, :g]}}

  # pass returns false
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c, :g], :c=>Trailblazer::Activity::Left}}
    end

    it "provides {pass} and allows {Output()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c, Output(:failure) => Id(:b)
        # fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
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
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c, :g, :b]}}

  # pass returns false
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal     %{{:seq=>[:f, :c, :b], :c=>Trailblazer::Activity::Left}}
    end
  end

# {State} tests.

  it "provides defaults" do
    state = Activity::Railway::DSL::State.build(**Activity::Railway::DSL.OptionsForState)
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.fail task: implementing.method(:a), id: :a
    seq = state.step task: implementing.method(:g), id: :g
    seq = state.step task: implementing.method(:c), id: :c
    seq = state.fail task: implementing.method(:b), id: :b
    seq = state.step task: implementing.method(:d), id: :d

    assert_process seq, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "allows {Output() => Id()}" do
    state = Activity::Railway::DSL::State.build(**Activity::Railway::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f, state.Output(:failure) => state.Id(:g)
    seq = state.fail task: implementing.method(:a), id: :a
    seq = state.step task: implementing.method(:g), id: :g

    assert_process seq, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "allows {Output() => Track()}" do
    state = Activity::Railway::DSL::State.build(**Activity::Railway::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.fail task: implementing.method(:a), id: :a, state.Output(:success) => state.Track(:success)
    seq = state.step task: implementing.method(:g), id: :g

    assert_process seq, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "accepts {:adds}" do
    state = Activity::Railway::DSL::State.build(**Activity::Railway::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f, adds: [
      {row: [:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {id: :g}], insert: [Linear::Insert.method(:Prepend), :f]}]
    seq = state.fail task: implementing.method(:a), id: :a, adds: [
      {row: [:failure, implementing.method(:b), [Linear::Search.Forward(Activity.Output("f/signal", :failure), :failure)], {}], insert: [Linear::Insert.method(:Prepend), :g]}]
    # seq = state.pass implementing.method(:f), id: :f, adds: [[[:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {}], Linear::Insert.method(:Prepend), :f]]

    assert_process seq, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.b>
 {f/signal} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
  end

  describe "#pass" do
    it "accepts Railway as a builder" do
      skip
      activity = Module.new do
        extend Activity::Railway()
        step task: T.def_task(:a)
        pass task: T.def_task(:b)
        fail task: T.def_task(:c)
      end

      _(Cct(activity)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
    end
  end

  describe "{:end_task}, {:failure_end}" do
    it "allows to define custom End instances" do
      MyFailure = Class.new(Activity::End)
      MySuccess = Class.new(Activity::End)

      activity = Class.new(Activity::Railway(end_task: MySuccess.new(semantic: :my_success), failure_end: MyFailure.new(semantic: :my_failure))) do
        step task: T.def_task(:a)
      end

      _(activity.to_h[:outputs].inspect).must_equal %{[#<struct Trailblazer::Activity::Output signal=#<RailwayTest::MySuccess semantic=:my_success>, semantic=:my_success>, \
#<struct Trailblazer::Activity::Output signal=#<RailwayTest::MyFailure semantic=:my_failure>, semantic=:my_failure>]}

      assert_circuit activity.to_h, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<RailwayTest::MyFailure/:my_failure>
 {Trailblazer::Activity::Right} => #<RailwayTest::MySuccess/:my_success>
#<RailwayTest::MySuccess/:my_success>

#<RailwayTest::MyFailure/:my_failure>
}
    end
  end

end
