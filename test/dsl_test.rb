require "test_helper"

class DslTest < Minitest::Spec
  def assert_sequence(sequence, *args)
    assert_process_for Activity::DSL::Linear::Compiler.(sequence), *args
  end

  Imp = T.def_tasks(:a, :b, :c, :d, :f, :g)

  it "API specification, return values" do
  #@ {#build} returns the initial sequence
    path, sequence = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())

    assert_sequence sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

  #@ {#step} returns sequence
    sequence = path.step implementing.method(:d)

    assert_sequence sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "provides {DSL} instance that doesn't compile the activity" do
    path, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())

    implementing = self.implementing

    # The DSL::Instance instance is the only mutable object.
    path.instance_exec do
      step implementing.method(:c), path.Output("New", :new) => path.End(:new)
      step implementing.method(:d)
    end

    sequence = path.to_h[:sequence]

    schema = Activity::DSL::Linear::Compiler.(sequence)

    assert_process_for schema, :success, :new, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
 {New} => #<End/:new>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:new>
}
  end

  it "Path() helper uses same options as outer Sequencer" do
    shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}

    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(**shared_options))

    state.step Imp.method(:a), id: :a, state.Output(:success) => state.Path(end_id: "End.path", end_task: state.End(:path)) do
      step Imp.method(:c), id: :c
    end
    state.step Imp.method(:b), id: :b

    sequence = state.to_h[:sequence]

    assert_process sequence, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: DslTest::Imp.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: DslTest::Imp.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: DslTest::Imp.c>>
#<Fixtures::CircuitInterface:0x @step=#<Method: DslTest::Imp.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<Fixtures::CircuitInterface:0x @step=#<Method: DslTest::Imp.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:path>
}
  end

  it "importing helpers and constants" do
    Trailblazer::Activity::DSL::Linear::Helper.module_eval do # FIXME: make this less global!
      def MyHelper()
        {task: "Task", id: "my_helper.task"}
      end
    end

    module MyMacros
      def self.MyHelper()
        {task: "Task 2", id: "my_helper.task"}
      end
    end

    Trailblazer::Activity::DSL::Linear::Helper::Constants::My = MyMacros


    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    state.step state.MyHelper()

# FIXME: how are we gonna do this?
    # state.instance_exec do
    #   step My::MyHelper()
    # end

    sequence = state.to_h[:sequence]

    assert_process sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task\"
\"Task\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end
end
