require "test_helper"

class PathTest < Minitest::Spec
  Activity = Trailblazer::Activity

  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d, :f, :g)
    end
    implementing::Start = Activity::Start.new(semantic: :default)
    implementing::Failure = Activity::End(:failure)
    implementing::Success = Activity::End(:success)

    implementing
  end

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
    state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(end_task: Activity::End.new(semantic: :winning)))
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g

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
end
