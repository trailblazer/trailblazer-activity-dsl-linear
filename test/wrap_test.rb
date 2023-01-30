require "test_helper"
# FIXME: what is this test?

class TaskWrapTest < Minitest::Spec
  it "populates activity[:wrap_static] and uses it at run-time" do
    taskWrap = Trailblazer::Activity::TaskWrap

    # taskWrap extensions.
    merge = [
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append:  "task_wrap.call_task"],
    ]

    implementing = self.implementing
    activity = Class.new(Trailblazer::Activity::Path) do
      step task: implementing.method(:a), extensions: [taskWrap::Extension.WrapStatic(*merge)]
      step task: implementing.method(:b)
      step task: implementing.method(:c)
    end

    signal, (ctx, flow_options) = taskWrap.invoke(activity, [{seq: []}, {}])

    _(ctx.inspect).must_equal %{{:seq=>[1, :a, 2, :b, :c]}}

# {Activity.invoke} is an alias for {TaskWrap.invoke}
    signal, (ctx, flow_options) = activity.invoke([{seq: []}, {}], **{})

    _(ctx.inspect).must_equal %{{:seq=>[1, :a, 2, :b, :c]}}

# it works nested as well

    c = implementing.method(:c)

    nested_activity = Class.new(Trailblazer::Activity::Path) do
      step task: implementing.method(:a)
      step Subprocess(activity)
      step task: c, extensions: [taskWrap::Extension.WrapStatic(*merge)]
    end

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{})

    _(ctx.inspect).must_equal %{{:seq=>[:a, 1, :a, 2, :b, :c, 1, :c, 2]}}

# it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => taskWrap::Extension(*merge)}

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{wrap_runtime: wrap_runtime})

    assert_equal ctx.inspect, %{{:seq=>[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]}}
  end
end
