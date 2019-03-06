require "test_helper"

# macro Output => End
# Output(NewSignal, :semantic)

class ActivityTest < Minitest::Spec
  describe "macro" do

    it "accepts {:before} in macro options" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        # step MyMacro()
        step({id: :b, task: implementing.method(:b), before: :a})
      end

      assert_process_for activity.to_h[:process], :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {:outputs}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        # step MyMacro()
        step({id: :b, task: implementing.method(:b), before: :a, outputs: {success: Activity.Output("Yo", :success)}})
      end

      assert_process_for activity.to_h[:process], :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Yo} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {Output() => End()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), before: :a, Linear.Output(:success) => Activity.End(:new)})
      end

      assert_process_for activity.to_h[:process], :success, :new, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:new>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:new>
}
    end

    it "accepts {Output() => Id()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), Linear.Output(:success) => Linear.Id(:a)})
      end

      assert_process_for activity.to_h[:process], :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}
    end

    it "accepts {:connections}" do
      implementing = self.implementing

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a
        step({id: :b, task: implementing.method(:b), connections: {success: [Linear::Search.method(:ById), :a]}})
      end

      assert_process_for activity.to_h[:process], :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
#<End/:success>
}
    end

    it "accepts {:adds}" do
      implementing = self.implementing

      circuit_interface_tasks = T.def_tasks(:c)

      activity = Class.new(Activity::Path) do
        step implementing.method(:a), id: :a

        row = Linear::Sequence.create_row(task: circuit_interface_tasks.method(:c), id: :c, magnetic_to: :success,
            wirings: [Linear::Search::Forward(Activity.Output(Activity::Right, :success), :success)])

        step({id: :b, task: implementing.method(:b), adds: [

          [
            row,
            Linear::Insert.method(:Prepend), :a
          ]]
        })
      end

      assert_process_for activity.to_h[:process], :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
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
