require "test_helper"

class ActivityTest < Minitest::Spec
  describe "::task with macro style" do
    it "accepts sequence_options" do
      raise "macro that adds :before"

      activity = Module.new do
        extend Trailblazer::Activity::Path()

        task task: A, id: "a"
        task task: B, before: "a", id: "b"
      end

      assert_path activity, %{
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => ActivityTest::A
 {Trailblazer::Activity::Left} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
}
    end
  end



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

  describe "#merge!" do
    it "what" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step implementing.method(:b), id: :b
      end

      sub_activity = Class.new(Activity::Path) do
        step implementing.method(:c), id: :c
        merge!(activity)
        step implementing.method(:d), id: :d
      end

      process = sub_activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end

  describe "Path()" do
    it "allows referencing the activity classes' methods in the {Path} block" do
      activity = Class.new(Activity::Path) do
        extend T.def_tasks(:a, :b, :c)

        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do |path|
          path.step method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h[:process]

    assert_process_for process, :path, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.a>>
<*#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Class:0x>.c>>
<*#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<End/:path>

<*#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "allows customized options" do
      shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}
      # state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(**shared_options))

      activity = Class.new(Activity::Path(shared_options)) do
        extend T.def_steps(:a, :b, :c)

        step method(:a), id: :a, Output(:success) => Path(end_id: "End.path", end_task: End(:path)) do |path|
          path.step method(:c), id: :c
        end
        step method(:b), id: :b
      end

      process = activity.to_h[:process]

    assert_process_for process, :path, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<End/:path>

#<Fixtures::CircuitInterface:0x @step=#<Method: #<Class:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end




  # inheritance
  # macaroni
  # Path() with macaroni
  # merge!
  # :step_method
  # :extension API/state for taskWrap, also in Path()
end
