require "test_helper"

class SequencerTest < Minitest::Spec
  Imp = T.def_tasks(:a, :b, :c, :d, :f, :g)

  let(:helper) { Activity::Railway }

  it "builds a Sequence" do
    options = Activity::Path::DSL.OptionsForSequencer()
    # raise options.keys.inspect

    sequence = Activity::DSL::Linear::Sequencer.(:step, Imp.method(:a), {id: :a}, **options)

    assert_process sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: SequencerTest::Imp.a>>
<*#<Method: SequencerTest::Imp.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "Path() helper uses same options as outer Sequencer" do
    shared_options = {step_interface_builder: Fixtures.method(:circuit_interface_builder)}

    block = ->(*) do
      step Imp.method(:c), id: :c
    end

    options = Activity::Path::DSL.OptionsForSequencer(**shared_options)


    sequence = Activity::DSL::Linear::Sequencer.(:step, Imp.method(:a), {id: :a, helper.Output(:success) => helper.Path(end_id: "End.path", end_task: helper.End(:path))},
      **options,
      &block
    )

    # state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(**shared_options))

    # state.step Imp.method(:a), id: :a, state.Output(:success) => state.Path(end_id: "End.path", end_task: state.End(:path)) do
    #   step Imp.method(:c), id: :c
    # end
    # state.step Imp.method(:b), id: :b

    # sequence = state.to_h[:sequence]

    assert_process sequence, :success, :path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: SequencerTest::Imp.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: SequencerTest::Imp.a>>
 {Trailblazer::Activity::Right} => <*#<Method: SequencerTest::Imp.c>>
<*# circuit interface <Method: SequencerTest::Imp.c>>
 {Trailblazer::Activity::Right} => #<End/:path>
#<End/:success>

#<End/:path>
}
  end
end
