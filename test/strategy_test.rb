require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)

    assert_equal CU.strip(CU.inspect(strategy.to_h[:sequence])), %(#<Trailblazer::Activity::DSL::Linear::Sequence:0x @sequence=[[\"Start.default\", #<struct Trailblazer::Activity::DSL::Linear::Sequence::Row magnetic_to=nil, task=#<Trailblazer::Activity::Start semantic=:default>, wirings=[], data=#{{:id=>"Start.default"}.inspect}, task_wrap=#{CU.strip(Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP.inspect)}>]]>)

    assert_circuit strategy.to_h, %{
#<Start/:default>
}
  end

  let(:default_normalizer_extensions_in_fields) { {normalizer_extensions: Trailblazer::Activity::DSL::Linear::Strategy::INITIAL_NORMALIZER_EXTENSIONS} }

#@ State-relevant tests
  it "provides {:fields} in {@state} which is an (inherited) hash" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)

    sub      = Class.new(strategy)
    sub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(representer: Module) }

    subsub   = Class.new(sub)
    subsub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(policy: Object) }

    assert_equal strategy.to_h[:fields], default_normalizer_extensions_in_fields # only contains library defaults, no user fields, yet.
    assert_equal sub.to_h[:fields], default_normalizer_extensions_in_fields.merge(representer: Module)
    assert_equal subsub.to_h[:fields], default_normalizer_extensions_in_fields.merge(representer: Module, policy: Object)
  end

#@ Strategy API
  it "{Strategy#to_h} represents an interface for accessing internal data structures" do
    activity = Class.new(Activity::Path) do
      step :model
    end

    hsh = activity.to_h

    assert_equal hsh.keys.inspect, %{[:circuit, :outputs, :nodes, :config, :activity, :sequence, :fields]}
    assert_equal hsh[:activity].class, Trailblazer::Activity
    assert_equal hsh[:sequence].class, Trailblazer::Activity::DSL::Linear::Sequence
    assert_equal hsh[:sequence].to_a.size, 3 # DISCUSS: private API.
    assert_equal hsh[:fields], default_normalizer_extensions_in_fields # FIXME: get the Pipeline vs. ary conflict sorted.
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
    ctx, _, signal = activity.invoke(ctx, {}, start_task: start_task)

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
