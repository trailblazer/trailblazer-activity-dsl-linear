require "test_helper"

class StrategyTest < Minitest::Spec
  describe "Path" do
    it "#initial_sequence" do
      seq = Trailblazer::Activity::Path::DSL.initial_sequence

      Cct(process: compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end

  describe "Railway" do
    it "#initial_sequence" do
      seq = Trailblazer::Activity::Railway::DSL.initial_sequence

      Cct(process: compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    end
  end

  describe "FastTrack" do
    it "#initial_sequence" do
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence

      Cct(process: compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    end
  end
end
