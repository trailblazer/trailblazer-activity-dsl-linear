require "test_helper"

class InjectTest < Minitest::Spec
  it "Inject(circuit_interface: true)" do
    module XX
      class Create < Trailblazer::Activity::Railway
        #@ Inject with :instance_method
        #@        with [:array]
        step :write,
          Inject(:current_user) => :my_instance_method_for_current_user, # TODO: document.
          Inject() => [:date, :time],
          Inject() => [:month],
          Inject() => {
            year: ->(ctx, date:, **) { "<Year of #{date}>" },
            never: ->(ctx, never:, call:, **) { raise "i shouldn't be called!" },
          },
          In() => [:model],
          # In() => [:date],
          In() => {:something => :thing}

        def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
          ctx[:log] = %{
ctx keys:     #{ctx.keys.inspect}
time:         #{time.inspect}
date:         #{date}
current_user: #{current_user}
ctx[:model]:  #{ctx[:model]}
ctx[:thing]:  #{ctx[:thing].inspect}
ctx[:year]:   #{ctx[:year].inspect}
ctx[:month]:  #{ctx[:month].inspect}
}
        end

        def my_instance_method_for_current_user(ctx, model:, **)
          "<Currentuser for #{model}>"
        end
      end
    end # XX

  #@ {:month} is not here
    assert_invoke XX::Create, never: true, time: "yesterday", date: "today", model: Object, expected_ctx_variables: {
      log: %{
ctx keys:     [:model, :thing, :current_user, :date, :time, :year, :never]
time:         "yesterday"
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  nil
ctx[:year]:   "<Year of today>"
ctx[:month]:  nil
}
    }

  #@ {:something} is mapped via In
    assert_invoke XX::Create, never: true, time: "yesterday", date: "today", model: Object, something: 99, expected_ctx_variables: {
      log: %{
ctx keys:     [:model, :thing, :current_user, :date, :time, :year, :never]
time:         "yesterday"
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "<Year of today>"
ctx[:month]:  nil
}
    }

  #@ {:time} is defaulted in {#write}
    assert_invoke XX::Create, never: true, date: "today", model: Object, something: 99, expected_ctx_variables: {
      log: %{
ctx keys:     [:model, :thing, :current_user, :date, :year, :never]
time:         "Time.now"
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "<Year of today>"
ctx[:month]:  nil
}
    }

  #@ {:time} is defaulted in {#write}
  #@ {:year} is passed-through
    assert_invoke XX::Create, never: true, date: "today", model: Object, something: 99, year: "2022", expected_ctx_variables: {
      log: %{
ctx keys:     [:model, :thing, :current_user, :date, :year, :never]
time:         "Time.now"
date:         today
current_user: <Currentuser for Object>
ctx[:model]:  Object
ctx[:thing]:  99
ctx[:year]:   "2022"
ctx[:month]:  nil
}
    }
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

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(variable_name: :model, filter: filter, user_filter: user_filter, name: :model)


      ctx = {current_user: Object, mode: :update}


      wrap_ctx = {aggregate: {}}


      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {exec_context: my_exec_context}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
    end

    it "SetVariable#call can invoke any self-made circuit-step interface filter" do
      my_lowlevel_inject_filter = ->((ctx, flow_options), **) { "<MyModel #{ctx.fetch(:current_user)}>" }

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(variable_name: :model, filter: my_lowlevel_inject_filter, user_filter: my_lowlevel_inject_filter, name: :model)


      ctx = {current_user: Object, mode: :update}


      wrap_ctx = {aggregate: {}}


      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
      end


  end
end
