require "test_helper"

class RailwayTest < Minitest::Spec
  it "#initial_sequence" do
    seq = Trailblazer::Activity::Railway::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success")

    Cct(process: compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

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
    seq = state.step task: implementing.method(:f), id: :f, adds: [[[:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {id: :g}], Linear::Insert.method(:Prepend), :f]]
    seq = state.fail task: implementing.method(:a), id: :a, adds: [[[:failure, implementing.method(:b), [Linear::Search.Forward(Activity.Output("f/signal", :failure), :failure)], {}], Linear::Insert.method(:Prepend), :g]]
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
