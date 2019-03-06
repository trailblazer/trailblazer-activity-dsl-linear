require "test_helper"

class PathTest < Minitest::Spec
  it "#initial_sequence" do
    seq = Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")

    Cct(compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "provides defaults" do
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState)
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(track_name: :green))
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g

    seq[1][0].must_equal :green

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

  it "accepts {:end}" do
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(end_task: Activity::End.new(semantic: :winning), end_id: "End.winner"))
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g

    seq.last[3][:id].must_equal "End.winner"

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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:g), id: :g, Linear.Output(:success) => Linear.Id(:f)
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState())
    seq = state.step task: implementing.method(:f), id: :f
    seq = state.step task: implementing.method(:a), id: :a, delete: :f

    assert_process seq, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  describe "Path()" do
    it "accepts {:end_task} and {:end_id}" do
      path_end = Activity::End.new(semantic: :roundtrip)

      state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState())
      state.step( task: implementing.method(:a), id: :a, Linear.Output(:failure) => Linear.Path(end_task: path_end, end_id: "End.roundtrip") do |path|
        path.step task: implementing.method(:f), id: :f
        path.step task: implementing.method(:g), id: :g
      end
      )
      state.step task: implementing.method(:b), id: :b, Linear.Output(:success) => Linear.Id(:a)
      state.step task: implementing.method(:c), id: :c, Linear.Output(:success) => Linear.End(:new)
      seq = state.fail task: implementing.method(:d), id: :d#, Linear.Output(:success) => Linear.End(:new)


      process = assert_process seq, :roundtrip, :success, :new, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<End/:roundtrip>

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

#<End/:failure>
}

      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], a: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:roundtrip>}
      ctx.inspect.must_equal     %{{:seq=>[:a, :f, :g], :a=>false}}
    end

    it "allows using a different task builder, etc" do
      implementing = Module.new do
        extend Activity::Testing.def_steps(:a, :f, :b) # circuit interface.
      end

      path_end = Activity::End.new(semantic: :roundtrip)

      shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}
      state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(**shared_options))

      state.step( implementing.method(:a), id: :a, Linear.Output(:success) => Linear.Path(end_task: path_end, end_id: "End.roundtrip", **shared_options) do |path|
        path.step implementing.method(:f), id: :f
      end
      )
      seq = state.step implementing.method(:b), id: :b, Linear.Output(:success) => Linear.Id(:a)


      process = assert_process seq, :roundtrip, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<End/:roundtrip>

#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<End/:success>
}

      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], a: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:roundtrip>}
      ctx.inspect.must_equal     %{{:seq=>[:a, :f], :a=>false}}
    end
  end

end
