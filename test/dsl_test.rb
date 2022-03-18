require "test_helper"

class DslTest < Minitest::Spec
  Imp = T.def_tasks(:a, :b, :c, :d, :f, :g)

  it "Path() {}" do
    shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}

    state = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(**shared_options))

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
end
