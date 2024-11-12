require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)

    assert_equal strategy.to_h[:sequence].inspect, %{[[nil, #<Trailblazer::Activity::Start semantic=:default>, [], #{{:id=>"Start.default"}}]]}

    assert_circuit strategy.to_h, %{
#<Start/:default>
}
  end

#@ State-relevant tests
  it "provides {:fields} in {@state} which is an (inherited) hash" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)

    sub      = Class.new(strategy)
    sub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(representer: Module) }

    subsub   = Class.new(sub)
    subsub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(policy: Object) }

  #= initial is empty
    assert_equal strategy.instance_variable_get(:@state).get(:fields).inspect, "{}"
    assert_equal CU.inspect(sub.instance_variable_get(:@state).get(:fields)), "{:representer=>Module}"
    assert_equal CU.inspect(subsub.instance_variable_get(:@state).get(:fields)), "{:representer=>Module, :policy=>Object}"
  end

#@ DSL tests
  it "importing helpers and constants" do
  #@ we can add methods to {Helper}. # TODO: document us!
    Trailblazer::Activity::DSL::Linear::Helper.module_eval do # FIXME: make this less global!
      def MyHelper()
        {task: "Task", id: "my_helper.task"}
      end
    end

    module MyMacros
      def self.MyHelper()
        {task: "Task 2", id: "my_helper.task"}
      end
    end

  #@ we can add constants to {Helper::Constants}.
    Trailblazer::Activity::DSL::Linear::Helper::Constants::My = MyMacros

    strategy = Class.new(Trailblazer::Activity::Path) # DISCUSS: should this be just {Linear::Strategy}?
    strategy.instance_exec do
      step MyHelper()
    end


    assert_circuit strategy, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task\"
\"Task\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    strategy = Class.new(Trailblazer::Activity::Path)
    strategy.class_eval <<-EOS
      step My::MyHelper()
EOS

    assert_circuit strategy, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task 2\"
\"Task 2\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "{Strategy.invoke} runs activity using taskWrap" do
    activity = Class.new(Activity::Railway) do
      step :dont_run_me
      step :find_model, Out() => [:model]
      step :save

      include T.def_steps(:find_model, :save)
    end

    start_task = Activity::Introspect.Nodes(activity, id: :find_model).task
    ctx = {seq: []}
    #@ Positionals and kwargs are passed on:
    signal, (ctx, _) = activity.invoke([ctx, {}], start_task: start_task)

    assert_equal signal.to_h[:semantic], :success
    # The presence of {:model} here means taskWrap extensions have been run.
    assert_equal CU.inspect(ctx), %{{:seq=>[:find_model, :save], :model=>nil}}
  end


  it "allows {Introspect.Nodes()}" do
    activity = Class.new(Activity::Railway) do
      step :a
    end

    assert_equal Activity::Introspect.Nodes(activity, id: :a).id, :a
  end

  it "all strategies expose correct terminus data" do
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Path, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Railway, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Railway, id: "End.failure").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:failure})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.failure").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:failure})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.fail_fast").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:fail_fast})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.pass_fast").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:pass_fast})
  end
end
