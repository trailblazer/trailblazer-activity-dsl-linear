require "test_helper"

class RailwayTest < Minitest::Spec
  it "#initial_sequence" do
    seq = Trailblazer::Activity::Railway::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")

    Cct(compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
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

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a, :b], :f=>false}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :b], :g=>false}}
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

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track, {a} goes back to success
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false, a: true}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a, :g, :c, :d], :f=>false, :a=>true}}

  # left track, {a} stays on failure
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false, a: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a, :b], :f=>false, :a=>false}}

  # {d} goes to {b}
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], d: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c, :d, :b], :d=>false}}
    end

    it "provides {pass}" do
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

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :c, :g]}}

  # pass returns false
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :c, :g], :c=>false}}
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

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :c, :g, :b]}}

  # pass returns false
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :c, :b], :c=>false}}
    end
  end

# {State} tests.

  it "provides defaults" do
    state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState)
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
    state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f, Linear.Output(:failure) => Linear.Id(:g)
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
    state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.fail task: implementing.method(:a), id: :a, Linear.Output(:success) => Linear.Track(:success)
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
    state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState())
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

      Cct(activity).must_equal %{
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

  describe ":track_end and :failure_end" do
    it "allows to define custom End instance" do
      skip
      class MyFail; end
      class MySuccess; end

      activity = Module.new do
        extend Activity::Railway( track_end: MySuccess, failure_end: MyFail )

        step task: T.def_task(:a)
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => RailwayTest::MySuccess
 {Trailblazer::Activity::Left} => RailwayTest::MyFail
RailwayTest::MySuccess

RailwayTest::MyFail
}
    end
  end


    # normalizer
end
