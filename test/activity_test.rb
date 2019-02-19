require "test_helper"

class ActivityTest < Minitest::Spec
  it "allows inheritance / INSERTION options" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step implementing.method(:a), id: :a
      step implementing.method(:b), id: :b
    end

    sub_activity = Class.new(activity) do
      step implementing.method(:c), id: :c
      step implementing.method(:d), id: :d
    end

    sub_sub_activity = Class.new(sub_activity) do
      step implementing.method(:g), id: :g, before: :b
      step implementing.method(:f), id: :f, replace: :a
      step nil,                             delete: :c
    end

    process = activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_sub_activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "allows, when inheritance time, to inject normalizer options" do
    implementing = Module.new do
      extend Activity::Testing.def_steps(:a, :f, :b) # circuit interface.
    end

    activity = Class.new(Activity::Path(step_interface_builder: Fixtures.method(:circuit_interface_builder))) do
      step implementing.method(:a), id: :a
      step implementing.method(:b), id: :b
    end

    sub_activity = Class.new(activity) do
      step implementing.method(:f), id: :f
    end

    process = activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}


    process = sub_activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end



  # Path() with macaroni
  # merge!
  # inheritance
  # :step_method
  # macaroni
end
