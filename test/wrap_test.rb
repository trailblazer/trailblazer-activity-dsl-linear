require "test_helper"

# Test for DSL options related to taskWrap.
#
# using {:extensions} with {WrapStatic} is a taskWrap specific "feature".
# {:initial_task_wrap} option is tw-specific

class TaskWrapTest < Minitest::Spec
  it "{:initial_task_wrap} is defaulted to [<call_task>]" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step task: Object
    end

    task_wrap = activity.to_h[:config][:wrap_static][Object]

    assert_equal task_wrap.to_a.collect { |step| step.id }, ["task_wrap.call_task"]
  end

  it "the {:initial_task_wrap_extensions} option allows to produce a custom taskWrap" do
    tw_step = ->(wrap_ctx, original_args) do
      wrap_ctx[:return_signal] = Trailblazer::Activity::Right
      wrap_ctx[:return_args] = [{seq: "hello from taskWrap"}]
      return wrap_ctx, original_args
    end

    activity = Class.new(Trailblazer::Activity::Railway) do
      my_ext = Trailblazer::Activity::TaskWrap.Extension([tw_step, id: "my.add_1", prepend: nil]) # no {call_task} anymore.

      step task: Object, initial_task_wrap_extensions: [my_ext]
    end

    task_wrap = activity.to_h[:config][:wrap_static][Object]

    assert_equal task_wrap.to_a.collect { |step| step.id }, ["my.add_1"]

    assert_invoke activity, seq: %("hello from taskWrap")
  end

  # TODO: should we test if {:initial_task_wrap_extensions} is defaulted?
  # TODO: what happens in a Subprocess where we need to merge both, from the activity and from the DSL user?

  it "populates activity[:wrap_static] and uses it at run-time" do
    taskWrap = Trailblazer::Activity::TaskWrap

    # taskWrap extensions.
    merge = [
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append:  "task_wrap.call_task"],
    ]

    implementing = self.implementing
    activity = Class.new(Trailblazer::Activity::Path) do
      step task: implementing.method(:a), Extension() => taskWrap::Extension.WrapStatic(*merge)
      step task: implementing.method(:b)
      step task: implementing.method(:c)
    end

    signal, (ctx, flow_options) = taskWrap.invoke(activity, [{seq: []}, {}])

    assert_equal CU.inspect(ctx), %{{:seq=>[1, :a, 2, :b, :c]}}

# {Activity.invoke} is an alias for {TaskWrap.invoke}
    signal, (ctx, flow_options) = activity.invoke([{seq: []}, {}], **{})

    assert_equal CU.inspect(ctx), %{{:seq=>[1, :a, 2, :b, :c]}}

# it works nested as well

    c = implementing.method(:c)

    nested_activity = Class.new(Trailblazer::Activity::Path) do
      step task: implementing.method(:a)
      step Subprocess(activity)
      step task: c, Extension() => taskWrap::Extension.WrapStatic(*merge)
    end

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{})

    assert_equal CU.inspect(ctx), %{{:seq=>[:a, 1, :a, 2, :b, :c, 1, :c, 2]}}

# it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => taskWrap::Extension(*merge)}

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{wrap_runtime: wrap_runtime})

    assert_equal CU.inspect(ctx), %{{:seq=>[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]}}
  end
end
