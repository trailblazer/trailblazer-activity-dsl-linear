require "test_helper"

class InjectTest < Minitest::Spec
  it "Inject(circuit_interface: true)" do
    module XX
      class Create < Trailblazer::Activity::Railway
        step :write,
          Inject(:current_user) => :my_instance_method,
          Inject() => [:date, :time],
          # Inject() => {current_user: ->(ctx, **) { ctx.keys.inspect }},
          In() => [:model],
          # In() => [:date],
          In() => {:something => :thing}

        def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
          ctx[:log] = "Called @ #{time} and #{date.inspect} by #{current_user}!"
          ctx[:private] = ctx.keys.inspect
          ctx[:private] += ctx[:model].inspect
        end

        def my_instance_method(ctx, model:, **)
          {current_user: "<Currentuser for #{model}>", date: 1}
        end
      end
    end # XX

    assert_invoke XX::Create, time: "yesterday", date: "today", model: Object, expected_ctx_variables: {
      log: "Called @ yesterday and \"today\" by [:seq, :time, :date, :model]{:seq=>[], :time=>\"yesterday\", :date=>\"today\", :model=>Object}!",
      private: "[:seq, :time, :date, :model, :current_user, :log]"
    }

  ## we can only see variables combined from Inject() and In() in the step.
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TT::Create, [{date: "today", model: Object, something: 99}, {}])
    assert_equal ctx.inspect, '{:date=>"today", :model=>Object, :something=>99, :log=>"Called @ Time.now and \"today\" by [:date, :model, :something]!", :private=>"[:model, :thing, :date, :current_user, :log]Object"}'
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

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(variable_name: :model, filter: filter, user_filter: user_filter)


      ctx = {current_user: Object, mode: :update}


      wrap_ctx = {aggregate: {}}


      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {exec_context: my_exec_context}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
    end

    it "SetVariable#call can invoke any self-made circuit-step interface filter" do
      my_lowlevel_inject_filter = ->((ctx, flow_options), **) { "<MyModel #{ctx.fetch(:current_user)}>" }

      pipe_task = Trailblazer::Activity::DSL::Linear::VariableMapping::SetVariable.new(variable_name: :model, filter: my_lowlevel_inject_filter, user_filter: my_lowlevel_inject_filter)


      ctx = {current_user: Object, mode: :update}


      wrap_ctx = {aggregate: {}}


      wrap_ctx, _ = pipe_task.(wrap_ctx, [[ctx, {}], {}])

      assert_equal wrap_ctx[:aggregate], {:model=>"<MyModel Object>"}
      end


  end
end
