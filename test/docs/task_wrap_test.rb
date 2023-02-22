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

class DocsRuntimeExtensionTest < Minitest::Spec
  module Song
  end

  module MyAPM # Advanced performance monitoring, done right!
    Store = []
    Span = Struct.new(:name, :payload, :finish_data) do
      def finish(data:)
        self.finish_data = data
      end
    end

    def self.start_span(name, payload:)
      Store << span = Span.new(name, payload)
      span
    end
  end

  module MyAPM # Advanced performance monitoring, done right!
    module Extension
      def self.start_instrumentation(wrap_ctx, original_args)
        (ctx, _flow_options), circuit_options = original_args

        activity  = circuit_options[:activity] # currently running Activity.
        task      = wrap_ctx[:task]            # the current "step".

        task_id   = Trailblazer::Activity::Introspect.Nodes(activity, task: task).id

        span      = MyAPM.start_span("operation.step", payload: {id: task_id})

        wrap_ctx[:span] = span

        return wrap_ctx, original_args
      end
    end
  end

  module MyAPM # Advanced performance monitoring, done right!
    module Extension
      def self.finish_instrumentation(wrap_ctx, original_args)
        ctx   = original_args[0][0]
        span  = wrap_ctx[:span]

        span.finish(data: ctx.inspect)

        return wrap_ctx, original_args
      end
    end
  end

  # APM, instrumentation

  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :model
      step :validate
      step :save
      #~meths
      include T.def_steps(:model, :validate, :save)
      #~meths end
    end
  end


  it "runs new taskWrap steps" do
    ext = Trailblazer::Activity::TaskWrap::Extension(
      [MyAPM::Extension.method(:start_instrumentation),  id: "my_apm.start_span",  prepend: "task_wrap.call_task"],
      [MyAPM::Extension.method(:finish_instrumentation), id: "my_apm.finish_span", append: "task_wrap.call_task"],
    )

    ctx = {song: {title: "Timebomb"}, seq: []}

    my_wrap = Hash.new(ext)

    signal, (ctx, _) = Song::Activity::Create.invoke([ctx, {}], wrap_runtime: my_wrap)

    assert_equal signal.to_h[:semantic], :success
    assert_equal ctx.inspect, %{{:song=>{:title=>\"Timebomb\"}, :seq=>[:model, :validate, :save]}}
    assert_equal MyAPM::Store.collect { |span| span.payload }.inspect, %{[{:id=>nil}, {:id=>\"Start.default\"}, {:id=>:model}, {:id=>:validate}, {:id=>:save}, {:id=>\"End.success\"}]}
  end
end

class DocsWrapStaticExtensionTest < Minitest::Spec
  module Song
  end

  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :model
      step :validate
      step :save
      #~meths
      include T.def_steps(:model, :validate, :save)
      #~meths end
    end
  end
end
