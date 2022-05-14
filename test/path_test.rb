require "test_helper"

class PathTest < Minitest::Spec
  Implementing = T.def_steps(:a, :b, :c, :d, :f, :g)

  it "empty Path subclass" do
    path = Class.new(Activity::Path) do
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_call path
  end

  it "Path exposes {#step}" do
    path = Class.new(Activity::Path) do
      include Implementing
      step :a
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_call path, seq: "[:a]"
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

end
