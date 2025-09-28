require "test_helper"

class InjectAlwaysOptionTest < Minitest::Spec
#@ we actually don't need {always: true}
#@ Inject() is always called.
  it "Inject(:name, always: true)" do
    class Create < Trailblazer::Activity::Railway
      step :write,
        Inject(:name) => ->(ctx, **) { ctx[:field] },
      #@ no {always: true}
        Inject() => [:date, :time],
        # TODO: deprecate this in favor of {Inject(:name)}.
        Inject(:year) => ->(ctx, date:, **) { "<Year of #{date}>" },
        Inject(:never) => ->(ctx, never:, call:, **) { raise "i shouldn't be called!" }


      def write(ctx, time: "Time.now", date:, current_user:, name:, **) # {date} has no default configured.
        ctx[:log] = %{
ctx keys:     #{ctx.keys.inspect}
time:         #{time.inspect}
ctx[:time]:   #{ctx[:time].inspect}
date:         #{date}
current_user: #{current_user}
ctx[:model]:  #{ctx[:model]}
ctx[:year]:   #{ctx[:year].inspect}

name:         #{name.inspect}
}
      end
    end

    assert_invoke Create, never: true, time: "yesterday", date: "today", model: Object, current_user: Module, field: :mode, expected_ctx_variables: {
      log: %{
ctx keys:     [:seq, :never, :time, :date, :model, :current_user, :field, :name, :year]
time:         "yesterday"
ctx[:time]:   "yesterday"
date:         today
current_user: Module
ctx[:model]:  Object
ctx[:year]:   "<Year of today>"

name:         :mode
}
    }
  end
end

class InjectTest < Minitest::Spec
  it "Inject(circuit_interface: true)" do
    module XX
      class Create < Trailblazer::Activity::Railway
        #@ Inject with :instance_method
        #@        with [:array]
        step :write,
          Inject(:current_user) => :my_instance_method_for_current_user, # TODO: document.
          Inject() => [:date, :time],
          Inject(:year) => ->(ctx, date:, **) { "<Year of #{date}>" },
          Inject(:never) => ->(ctx, never:, call:, **) { raise "i shouldn't be called!" },
          In() => [:model],
          # In() => [:date],
          In() => {:something => :thing},
          Inject(:months, override: true) => :my_months

        def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
          ctx[:log] = %{
ctx keys:     #{ctx.keys.inspect}
time:         #{time.inspect}
ctx[:time]:   #{ctx[:time].inspect}
date:         #{date}
current_user: #{current_user}
ctx[:model]:  #{ctx[:model]}
ctx[:thing]:  #{ctx[:thing].inspect}
ctx[:year]:   #{ctx[:year].inspect}
ctx[:months]: #{ctx[:months].inspect}
}
        end

        def my_instance_method_for_current_user(ctx, model:, **)
          "<Currentuser for #{model}>"
        end

        def my_months(ctx, **)
          [1,2,3]
        end
      end
    end # XX

  #@ {:something} is mapped via In
    assert_invoke XX::Create, never: true, time: "yesterday", date: "today", model: Object, something: 99, expected_ctx_variables: {
      log: %{
ctx keys:     [:current_user, :date, :time, :year, :never, :model, :thing, :months]
time:         "yesterday"
ctx[:time]:   "yesterday"
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "<Year of today>"
ctx[:months]: [1, 2, 3]
}
    }

  #@ {:time} is defaulted in {#write}
    assert_invoke XX::Create, never: true, date: "today", model: Object, something: 99, expected_ctx_variables: {
      log: %{
ctx keys:     [:current_user, :date, :year, :never, :model, :thing, :months]
time:         "Time.now"
ctx[:time]:   nil
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "<Year of today>"
ctx[:months]: [1, 2, 3]
}
    }

  #@ {:time} is defaulted in {#write}
  #@ {:year} is passed-through
    assert_invoke XX::Create, never: true, date: "today", model: Object, something: 99, year: "2022", expected_ctx_variables: {
      log: %{
ctx keys:     [:current_user, :date, :year, :never, :model, :thing, :months]
time:         "Time.now"
ctx[:time]:   nil
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "2022"
ctx[:months]: [1, 2, 3]
}
    }

#@ {:current_user} passed from outside, defaulting not called
    assert_invoke XX::Create, never: true, date: "today", model: Object, current_user: Module, expected_ctx_variables: {
      log: %{
ctx keys:     [:current_user, :date, :year, :never, :model, :thing, :months]
time:         "Time.now"
ctx[:time]:   nil
date:         today
current_user: Module
ctx[:model]:  Object
ctx[:thing]:  nil
ctx[:year]:   "<Year of today>"
ctx[:months]: [1, 2, 3]
}
    }

#@ {:months} passed from outside but still overridden by {Inject(:override => true)}
    assert_invoke XX::Create, never: true, date: "today", model: Object, months: "NO! I AM IGNORED!", expected_ctx_variables: {
      log: %{
ctx keys:     [:current_user, :date, :year, :never, :model, :thing, :months]
time:         "Time.now"
ctx[:time]:   nil
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  nil
ctx[:year]:   "<Year of today>"
ctx[:months]: [1, 2, 3]
}
    }

  end

  # DISCUSS: this test can, at some point, go away since this is basically a POC for trailblazer-invoke's Context() creation logic.
  it "Inject() => [] creates Context, and we are playing around with how to remove/omit the output pipe, because we don't want it in the one specific case of trb-invoke" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model, # this is what trb-invoke does for the actually run activity.
        Inject() => [],
        # initial_output_pipeline: Trailblazer::Activity::TaskWrap::Pipeline.new([])
        Extension(append: "variable_mapping") => Trailblazer::Activity::TaskWrap::Extension(
          [nil, id: nil, delete: "task_wrap.output"]
        )

      def model(ctx, model:, **)
        ctx[:ctx_in_model] = CU.inspect(ctx.inspect)
      end

    end

    # require "trailblazer/developer"
    # node, activity, _  = Trailblazer::Developer::Introspect.find_path(activity, [:model]) # FIXME: this breaks something with {:exec_context}!!!
    # pipe = Trailblazer::Developer::Render::TaskWrap.render_for(activity, node)
    # puts pipe
    # raise

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{model: Module}, {}])

    # pp ctx
    assert_equal ctx.class, Trailblazer::Context::Container
    assert_equal CU.inspect(ctx.inspect), %(#<Trailblazer::Context::Container wrapped_options={:model=>Module} mutable_options={:ctx_in_model=>\"#<Trailblazer::Context::Container wrapped_options={:model=>Module} mutable_options={}>\"}>)
  end

  it "{Extension}s can be evaluated after I/O extensions and can refer to them" do
    add_1_extension = Trailblazer::Activity::TaskWrap::Extension([method(:add_1), id: :add_1, prepend: "task_wrap.call_task"]) # see test_helper.rb
    add_2_extension = Trailblazer::Activity::TaskWrap::Extension([method(:add_2), id: :add_2, prepend: "task_wrap.output"]) # We're referencing an I/O taskWrap step.

    activity = Class.new(Activity::Path) do
      # Extension() is evaluated after In().
      step :model,
        Out()       => ->(ctx, seq:, **) { {seq: seq + [:output]} },
        Extension() => add_1_extension, # this is evaluated before "variable_mapping" and hence is the first tw step.
        Extension(append: "variable_mapping") => add_1_extension, # this is after "variable_mapping" and gets in front of {call_task}.
        Extension(append: "variable_mapping") => add_2_extension,
        In()        => ->(ctx, **) { {seq: ctx[:seq] += [:input]} }
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :input, 1, :model, 2, :output, :save]"
  end
end


class VariableMappingUnitTest < Minitest::Spec

  describe "SetVariable" do
    it "SetVariable#call can invoke a {Circuit.Step}" do
      my_exec_context = Class.new do
        def my_model(ctx, current_user:, **)
          "<MyModel #{current_user}>"
        end
      end.new

      user_filter = :my_model

      filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(write_name: :model, filter: filter, user_filter: user_filter, name: :model, _FIXME_wrap_with_hash: true)


      ctx = {current_user: Object, mode: :update}


      wrap_ctx = {aggregate: {}}


      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {exec_context: my_exec_context}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
    end

    it "SetVariable#call can invoke any self-made circuit-step interface filter" do
      my_lowlevel_inject_filter = ->((ctx, flow_options), **) { "<MyModel #{ctx.fetch(:current_user)}>" }

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(write_name: :model, filter: my_lowlevel_inject_filter, user_filter: my_lowlevel_inject_filter, name: :model, _FIXME_wrap_with_hash: true)

      ctx = {current_user: Object, mode: :update}

      wrap_ctx = {aggregate: {}}

      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
    end

    it "we can add a low-level filter via the DSL, ie to access {circuit_options}" do
      my_lowlevel_inject_filter = ->((ctx, flow_options), my_record:,**circuit_options) { "<MyModel #{my_record}>" }
      my_filter_builder = ->(*) { Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(name: "bla.FIXME", filter: my_lowlevel_inject_filter, write_name: :record, user_filter: nil, _FIXME_wrap_with_hash: true) }

      activity = Class.new(Trailblazer::Activity::Railway) do
        step :model,
          Inject(:record, filters_builder: my_filter_builder) => my_lowlevel_inject_filter

        def model(ctx, record:, **)
          ctx[:record_in_model] = record
        end
      end

      assert_invoke activity, circuit_options: {my_record: "Yay!"},
        expected_ctx_variables: {record_in_model: "<MyModel Yay!>"}
    end

  end
end
