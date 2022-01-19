require "test_helper"

class TaskWrapTest < Minitest::Spec
  it "populates activity[:wrap_static] and uses it at run-time" do
    taskWrap = Trailblazer::Activity::TaskWrap

    # taskWrap extensions.
    merge = [
      [taskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      [taskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]],
    ]

    implementing = self.implementing
    activity = Class.new(Trailblazer::Activity::Path) do
      step task: implementing.method(:a), extensions: [taskWrap::Extension(merge: merge)]
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
      step task: c, extensions: [taskWrap::Extension(merge: merge)]
    end

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{})

    _(ctx.inspect).must_equal %{{:seq=>[:a, 1, :a, 2, :b, :c, 1, :c, 2]}}

# it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => taskWrap::Pipeline::Merge.new(*merge)}

    signal, (ctx, flow_options) = taskWrap.invoke(nested_activity, [{seq: []}, {}], **{wrap_runtime: wrap_runtime})

    _(ctx.inspect).must_equal %{{:seq=>[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]}}
  end

end
