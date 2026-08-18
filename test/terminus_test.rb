require "test_helper"

class TerminusTest < Minitest::Spec
  MyHelper = Trailblazer::Activity::DSL::Feature::OutputTuples::Helper # FIXME: remove.

  it "#terminus" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      terminus :found
    end

    assert_equal my_activity.to_h[:outputs].keys, [:success, :failure, :found]
    assert_equal my_activity.to_h[:circuit].nodes[:"End.found"].task.nodes[:"task_wrap.call_task"].task.class, Trailblazer::Activity::Terminus::Success

    assert_run my_activity.to_h[:circuit], seq: [], terminus: my_activity.to_h[:circuit].nodes[:"End.success"].task.nodes[:"task_wrap.call_task"].task
  end

  it "accepts {:terminus_class}" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      terminus :not_found,
        terminus_class: Trailblazer::Activity::Terminus::Failure
    end

    assert_equal my_activity.to_h[:outputs].keys, [:success, :failure, :not_found]
    assert_equal my_activity.to_h[:circuit].nodes[:"End.not_found"].task.nodes[:"task_wrap.call_task"].task.class, Trailblazer::Activity::Terminus::Failure

    assert_run my_activity.to_h[:circuit], seq: [], terminus: my_activity.to_h[:circuit].nodes[:"End.success"].task.nodes[:"task_wrap.call_task"].task
  end

  it "sets {:magnetic_to}" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      terminus :found

      step :a, MyHelper.Output(:success) => MyHelper.Track(:found)

      include T.def_steps(:a)
    end

    assert_equal my_activity.to_h[:outputs].keys, [:success, :failure, :found]
    assert_equal my_activity.to_h[:circuit].nodes[:"End.found"].task.nodes[:"task_wrap.call_task"].task.class, Trailblazer::Activity::Terminus::Success

    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: my_activity.to_h[:circuit].nodes[:"End.found"].task.nodes[:"task_wrap.call_task"].task
  end

  it "#terminus with FastTrack" do
    my_activity = Class.new(Trailblazer::Activity::FastTrack) do
      terminus :found
    end

    assert_equal my_activity.to_h[:outputs].keys, [:success, :failure, :pass_fast, :fail_fast, :found]
    assert_equal my_activity.to_h[:circuit].nodes[:"End.found"].task.nodes[:"task_wrap.call_task"].task.class, Trailblazer::Activity::Terminus::Success

    assert_run my_activity.to_h[:circuit], seq: [], terminus: my_activity.to_h[:circuit].nodes[:"End.success"].task.nodes[:"task_wrap.call_task"].task
  end
end
