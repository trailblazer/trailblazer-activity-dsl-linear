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

    process = compile_process(seq)

    process.to_h[:outputs].inspect.must_equal %{[#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=:success>, semantic=:success>]}


    cct = Cct(process: process)
    cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end
end
