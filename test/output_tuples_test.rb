require "test_helper"

class OutputTuplesTest < Minitest::Spec
  let(:my_exec_context) { T.def_steps(:a) }

  MyExecContext = T.def_steps(:a) # TODO: use method(:a) instead of :a and remove {:exec_context} option, not part of this test!
  MyFailure = Trailblazer::Activity::Terminus::Success.new(semantic: :failure)
  MyHelper = Trailblazer::Activity::DSL::Feature::OutputTuples::Helper

  it "doesn't override existing {:wirings} because feature is skipped" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus
      step :a,
        # magnetic_to: :success,
        exec_context: MyExecContext,
        # adds_insertion_args: [:before, :success],
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success)}
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
      # flow_options: {application_ctx: {seq: [], a: "a success signal", success: "success signal"}}
  end

  it "without a specific layout normalizer, we can pass any tuples and get the appropriate {:wirings} for it" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)

      step :a,
        exec_context: MyExecContext,
        MyHelper.Output(:failure) => MyHelper.Track(:success), # failure becomes success.
        MyHelper.Output(:success) => MyHelper.Track(:failure),
        outputs: {
          # the concrete signals here will be used for the wirings.
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
        # this generates something like
        # wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success)}
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
  end

  it "only one output" do

  end

  it "output with custom signal" do
    my_exec_context = T.def_tasks(:a)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)

      step task: my_exec_context.method(:a), id: :a,
        MyHelper.Output(:failure) => MyHelper.Track(:failure),
        MyHelper.Output(:success, signal: Object) => MyHelper.Track(:success),
        outputs: {
          # the concrete signals here will be used for the wirings.
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Object}
    assert_raises KeyError do
      assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Right}
    end
  end

  it "three outputs, no third {:outputs} provided" do
    my_exec_context = T.def_tasks(:a)
    my_finished = Trailblazer::Activity::Terminus::Success.new(semantic: :finished)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)
      step **MyTest.options_for_mock_terminus(task: my_finished, semantic: :finished)

      step task: my_exec_context.method(:a), id: :a,
        MyHelper.Output(:failure) => MyHelper.Track(:failure),
        MyHelper.Output(:success) => MyHelper.Track(:success),
        MyHelper.Output(:finished, signal: Object) => MyHelper.Track(:finished),
        outputs: {
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: my_finished, target_ctx: {seq: [], a: Object}
  end

  it "three outputs, {:outputs} provided" do
    my_exec_context = T.def_tasks(:a)
    my_finished = Trailblazer::Activity::Terminus::Success.new(semantic: :finished)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)
      step **MyTest.options_for_mock_terminus(task: my_finished, semantic: :finished)

      step task: my_exec_context.method(:a), id: :a,
        MyHelper.Output(:failure) => MyHelper.Track(:failure),
        MyHelper.Output(:success) => MyHelper.Track(:success),
        MyHelper.Output(:finished) => MyHelper.Track(:finished), # we don't specify the "custom" signal here.
        outputs: {
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
          finished: Trailblazer::Activity::Output.new(Object, :finished),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: my_finished, target_ctx: {seq: [], a: Object}
  end

  it "Id()" do
    my_exec_context = T.def_tasks(:a, :b)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step **MyTest.options_for_mock_terminus

      my_generic_outputs = {
        success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
        failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
      }

      step task: my_exec_context.method(:a), id: :a,
        outputs: my_generic_outputs,
        MyHelper.Output(:failure) => MyHelper.Id(:b),
        MyHelper.Output(:success) => MyHelper.Track(:success)

      step task: my_exec_context.method(:b), id: :b,
        magnetic_to: :random,
        outputs: my_generic_outputs,
        MyHelper.Output(:success) => MyHelper.Track(:success)
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a, :b], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
  end


end
