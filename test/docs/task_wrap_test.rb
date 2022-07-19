require "test_helper"

class DocsTaskWrapTest < Minitest::Spec

  it "uses {:wrap_runtime} via {TaskWrap.invoke}" do
    #:run-logger
    module TaskWrapLogger
      def self.log_before(wrap_ctx, original_args)
        # Pick what you need here.
        (ctx, flow_options), circuit_options = original_args

        ctx[:log] << "Before #{wrap_ctx[:task]}"

        return wrap_ctx, original_args
      end
    end
    #:run-logger end

    #:op-run
    class Create < Trailblazer::Activity::Railway # or Trailblazer::Operation
      step :model
      step :save
      #~meth
      include T.def_steps(:model, :save)
      #~meth
    end
    #:op-run end

# DISCUSS: THIS IS OLD API, but needed in the docs
# TODO: test deprecation warning.
    #:run-merge
    merge = [
      [
        Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_before), # insert my step before
        "task_wrap.call_task",                                            # the {call_task} taskWrap step
        ["user.log_before", TaskWrapLogger.method(:log_before)]           # here's my own taskWrap step
      ],
      # ... add more, e.g. with {:insert_after}
      # [Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_after), ...
    ]

    wrap = Trailblazer::Activity::TaskWrap::Pipeline::Merge.new(*merge)

    wrap_runtime = Hash.new(wrap) # wrap_runtime[...] will always return the same wrap
    #:run-merge end

    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(Create, [{seq: [], log: []}, {}], wrap_runtime: wrap_runtime)
    ctx.inspect.must_equal %{{:seq=>[:model, :save], :log=>[\"Before DocsTaskWrapTest::Create\", \"Before #<Trailblazer::Activity::Start semantic=:default>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=model>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>\", \"Before #<Trailblazer::Activity::End semantic=:success>\"]}}
=begin
    #:run-invoke
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(
      Create,
      [{log: []}, {}],
      wrap_runtime: wrap_runtime
    )
    #:run-invoke end

    #:run-puts
    puts ctx[:log]
     => [
          "Before Create",
          "Before #<Trailblazer::Activity::Start semantic=:default>",
          "Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=model>"
          "Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>",
          "Before #<Trailblazer::Activity::End semantic=:success>",
        ]
    #:run-puts end
=end


  #@ new taskWrap API, the "friendly interface"
    default_ext = Trailblazer::Activity::TaskWrap::Extension(
      [TaskWrapLogger.method(:log_before), id: "user.log_before", prepend: "task_wrap.call_task"]
    )

    wrap_runtime = Hash.new(default_ext) # wrap_runtime[...] will always return the same wrap

    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(Create, [{seq: [], log: []}, {}], wrap_runtime: wrap_runtime)
    ctx.inspect.must_equal %{{:seq=>[:model, :save], :log=>[\"Before DocsTaskWrapTest::Create\", \"Before #<Trailblazer::Activity::Start semantic=:default>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=model>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>\", \"Before #<Trailblazer::Activity::End semantic=:success>\"]}}
  end
end
