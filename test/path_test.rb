require "test_helper"

class PathTest < Minitest::Spec
  it "provides defaults" do
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState)
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g

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
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g

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
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g

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
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g, Linear.Output(:success) => Linear.Id(:f)
    seq = state.step implementing.method(:a), id: :a

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
    seq = state.step implementing.method(:f), id: :f, adds: [[[:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {}], Linear::Insert.method(:Prepend), :f]]

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
end
