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
    CU.inspect(ctx).must_equal %{{:seq=>[:model, :save], :log=>[\"Before DocsTaskWrapTest::Create\", \"Before #<Trailblazer::Activity::Start semantic=:default>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=model>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>\", \"Before #<Trailblazer::Activity::End semantic=:success>\"]}}
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
    assert_equal CU.inspect(ctx), %{{:seq=>[:model, :save], :log=>[\"Before DocsTaskWrapTest::Create\", \"Before #<Trailblazer::Activity::Start semantic=:default>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=model>\", \"Before #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>\", \"Before #<Trailblazer::Activity::End semantic=:success>\"]}}
  end
end

class DocsRuntimeExtensionTest < Minitest::Spec
  module Song
  end

  module MyAPM # Advanced performance monitoring, done right!
    Store = []
    Span = Struct.new(:name, :payload, :finish_payload) do
      def finish(payload:)
        self.finish_payload = payload
      end
    end

    def self.start_span(name, payload:)
      Store << span = Span.new(name, payload)
      span
    end
  end

  it "what" do
    #:start
    span = MyAPM.start_span("validate", payload: {time: Time.now})
    # do whatever you have to...
    span.finish(payload: {time: Time.now})
    #:start end
  end

  #:myapm_start
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
  #:myapm_start end

  #:myapm
  module MyAPM # Advanced performance monitoring, done right!
    module Extension
      def self.finish_instrumentation(wrap_ctx, original_args)
        ctx   = original_args[0][0]
        span  = wrap_ctx[:span]

        span.finish(payload: ctx.inspect)

        return wrap_ctx, original_args
      end
    end
  end
  #:myapm end

  # APM, instrumentation

  #:create
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step :validate
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:create_model, :validate, :notify)
      #~meths end
    end
  end
  #:create end

  let(:apm_extension) do
    #:runtime_ext
    apm_extension = Trailblazer::Activity::TaskWrap::Extension(
      [MyAPM::Extension.method(:start_instrumentation),  id: "my_apm.start_span",  prepend: "task_wrap.call_task"],
      [MyAPM::Extension.method(:finish_instrumentation), id: "my_apm.finish_span", append: "task_wrap.call_task"],
    )
    #:runtime_ext end
  end

  it "runs apm steps around each step" do
    MyAPM::Store = []

    my_wrap = Hash.new(apm_extension)

    assert_invoke Song::Activity::Create,
      circuit_options: {wrap_runtime: my_wrap},
      song: {title: "Timebomb"},
      seq: "[:create_model, :validate, :notify]"

    assert_equal CU.inspect(MyAPM::Store.collect { |span| span.payload }.inspect), %([{:id=>nil}, {:id=>\"Start.default\"}, {:id=>:create_model}, {:id=>:validate}, {:id=>:notify}, {:id=>\"End.success\"}])

    #:runtime
    my_wrap = Hash.new(apm_extension)

    #:runtime_invoke
    Song::Activity::Create.invoke(
      [
        # ctx:
        {
          song: {title: "Timebomb"},
          #:meths
          seq: []
          #:meths end
        }
      ],
      wrap_runtime: my_wrap # runtime taskWrap extensions!
    )
    #:runtime_invoke end
    #:runtime end
  end

  it "runs apm only for {:validate}" do
    #:runtime_validate
    validate_task = Trailblazer::Activity::Introspect
      .Nodes(Song::Activity::Create, id: :validate) # returns Node::Attributes
      .task                                         # and the actually executed task from the circuit.

    my_wrap = {validate_task => apm_extension}
    #:runtime_validate end

    MyAPM::Store = []

    assert_invoke Song::Activity::Create,
      circuit_options: {wrap_runtime: my_wrap},
      song: {title: "Timebomb"},
      seq: "[:create_model, :validate, :notify]"

    assert_equal MyAPM::Store.collect { |span| span.payload }, [{:id=>:validate}]

  # the called activity itself is also taskWrapped!
    #:wrap_create
    my_wrap = {Song::Activity::Create => apm_extension}
    #:wrap_create end

    MyAPM::Store = []

    assert_invoke Song::Activity::Create,
      circuit_options: {wrap_runtime: my_wrap},
      song: {title: "Timebomb"},
      seq: "[:create_model, :validate, :notify]"

    assert_equal MyAPM::Store.collect { |span| span.payload }, [{:id=>nil}]

    my_wrap = {Song::Activity::Create => apm_extension}
  end
end

class DocsWrapStaticExtensionTest < Minitest::Spec
  module Song
  end
  MyAPM = DocsRuntimeExtensionTest::MyAPM

  #:static
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step :validate,
        Extension() => Trailblazer::Activity::TaskWrap::Extension::WrapStatic(
          [MyAPM::Extension.method(:start_instrumentation),  id: "my_apm.start_span",  prepend: "task_wrap.call_task"],
          [MyAPM::Extension.method(:finish_instrumentation), id: "my_apm.finish_span", append: "task_wrap.call_task"],
        )
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:create_model, :validate, :notify)
      #~meths end
    end
  end
  #:static end

  it "runs taskWrap extension only for {#validate}" do
    MyAPM::Store = []

    assert_invoke Song::Activity::Create,
      song: {title: "Timebomb"},
      seq: "[:create_model, :validate, :notify]"

    assert_equal MyAPM::Store.collect { |span| span.payload }, [{:id=>:validate}]

    ctx = {song: {title: "Timebomb"}, seq: []}

    #:static_invoke
    signal, (ctx, _) = Song::Activity::Create.invoke([ctx, {}])
    #:static_invoke end
  end
end
