require "test_helper"

class PathTest < Minitest::Spec
  Implementing = T.def_tasks(:a, :b, :c, :d, :f, :g)

  it "empty Path subclass" do
    path = Class.new(Activity::Path) do
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "Path exposes {#step}" do
    path = Class.new(Activity::Path) do
      step :a
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "exposes {#call}" do
    activity = Class.new(Activity::Path) do
      step Implementing.method(:a), id: :a
      step Implementing.method(:b)
    end

    assert_process_for activity.to_h, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: PathTest::Implementing.a>>
<*#<Method: PathTest::Implementing.a>>
 {Trailblazer::Activity::Right} => <*#<Method: PathTest::Implementing.b>>
<*#<Method: PathTest::Implementing.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    # Call without taskWrap!
    signal, (ctx, _) = activity.([{seq: []}, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:seq=>[:a, :b]}}
  end


  it "#initial_sequence" do
    seq = Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")

    _(Cct(compile_process(seq))).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "provides defaults" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState)
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:track_name}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(track_name: :green))
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g

    _(seq[1][0]).must_equal :green

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:end_task}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(end_task: Activity::End.new(semantic: :winning), end_id: "End.winner"))
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g

    _(seq.last[3][:id]).must_equal "End.winner"

    assert_process seq, :winning, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:winning>
#<End/:winning>
}
  end

  it "accepts {Output() => Id()}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g, state.Output(:success) => state.Id(:f)
    seq = state.step task: implementing.method(:a), id: :a

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:adds}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f, adds: [
      {
        row:    [:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {}],
        insert: [Linear::Insert.method(:Prepend), :f]
      }
    ]

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:before}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:a), id: :a, before: :f

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:after}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:b), id: :b
    seq = state.step task: implementing.method(:a), id: :a, after: :f

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:replace}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:a), id: :a, replace: :f

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:delete}" do
    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:a), id: :a, delete: :f

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  describe "Path()" do
    it "accepts {:end_task} and {:end_id}" do # TODO: don't use Railway here.
      path_end = Activity::End.new(semantic: :roundtrip)

      implementing = self.implementing
      state, _ = Activity::Railway::DSL::State.build(**Activity::Railway::DSL.OptionsForState())
      state.step(task: implementing.method(:a), id: :a, state.Output(:failure) => state.Path(end_task: path_end, end_id: "End.roundtrip") do
        step task: implementing.method(:f), id: :f
        step task: implementing.method(:g), id: :g
      end
      )
      state.step task: implementing.method(:b), id: :b, state.Output(:success) => state.Id(:a)
      state.step task: implementing.method(:c), id: :c, state.Output(:success) => state.End(:new)
      seq = state.fail task: implementing.method(:d), id: :d#, Linear.Output(:success) => Linear.End(:new)


      process = assert_process seq, :success, :new, :roundtrip, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:new>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:new>

#<End/:roundtrip>

#<End/:failure>
}

      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], a: Activity::Left}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:roundtrip>}
      _(ctx.inspect).must_equal     %{{:seq=>[:a, :f, :g], :a=>Trailblazer::Activity::Left}}
    end

    it "allows using a different task builder, etc" do
      implementing = Module.new do
        extend Activity::Testing.def_steps(:a, :f, :b) # circuit interface.
      end

      path_end = Activity::End.new(semantic: :roundtrip)

      shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}
      state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(**shared_options))

      implementing = self.implementing

      state.step(implementing.method(:a), id: :a, state.Output(:success) => state.Path(end_task: path_end, end_id: "End.roundtrip", **shared_options) do
        step implementing.method(:f), id: :f
      end
      )
      seq = state.step implementing.method(:b), id: :b, state.Output(:success) => state.Id(:a)


      process = assert_process seq, :success, :roundtrip, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<End/:success>

#<End/:roundtrip>
}

      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], a: false}])

      _(signal.inspect).must_equal  %{#<Trailblazer::Activity::End semantic=:roundtrip>}
      _(ctx.inspect).must_equal     %{{:seq=>[:a, :f], :a=>false}}
    end
  end

end
