require "test_helper"

# TODO: test all additional "features" of Normalizer::Step.
class Normalizer_Step_Test < Minitest::Spec
  it "we can use {:adds_for_task_wrap} to add steps" do
    my_extended_topology = MyTest.my_extended_topology(
      adds: [
        [:apply_adds_to_task_wrap_pipeline, Trailblazer::Activity::DSL::Feature::Extension::TaskWrap::Normalizer::Node, :before, :build_task_wrap_node]
      ],
    )

    my_topology = Class.new(my_extended_topology) do
      step :a,
        adds_for_task_wrap: [
          [
            :b,
            Trailblazer::Circuit::Node[T.def_tasks(:b).method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
            :before, :"task_wrap.call_task" # insert this step in :a's taskWrap but before :a is invoked.
          ]
        ],
        wirings: MyTest.wirings_for_terminus

      include T.def_steps(:a)
    end

    assert_run my_topology, seq: [:b, :a], terminus: Trailblazer::Activity::Right
  end
end
