require "test_helper"

class FastTrackTest < Minitest::Spec
  it "#initial_sequence" do
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")


      Cct(process: compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    end

  it "provides defaults" do
    state = Activity::FastTrack::DSL::State.new(Activity::FastTrack::DSL.OptionsForState)
    seq = state.step implementing.method(:f), id: :f
    seq = state.step implementing.method(:g), id: :g

    assert_process seq, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end






  it "accepts Railway as a builder" do
    activity = Module.new do
      extend Activity::Railway()
      step task: T.def_task(:a)
      step task: T.def_task(:b)
      fail task: T.def_task(:c)
    end

    Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
    end

  describe "#pass" do
    it "accepts Railway as a builder" do
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
