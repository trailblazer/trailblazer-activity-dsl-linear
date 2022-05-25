require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Linear::Strategy)

    assert_equal strategy.to_h[:sequence].inspect, %{[[nil, #<Trailblazer::Activity::Start semantic=:default>, [], {:id=>"Start.default"}]]}

    assert_circuit strategy.to_h, %{
#<Start/:default>
}
  end

#@ State-relevant tests
  it "provides {:fields} in {@state} which is an (inherited) hash" do
    strategy = Class.new(Linear::Strategy)

    sub      = Class.new(strategy)
    sub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(representer: Module) }

    subsub   = Class.new(sub)
    subsub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(policy: Object) }

  #= initial is empty
    assert_equal strategy.instance_variable_get(:@state).get(:fields).inspect, "{}"
    assert_equal sub.instance_variable_get(:@state).get(:fields).inspect, "{:representer=>Module}"
    assert_equal subsub.instance_variable_get(:@state).get(:fields).inspect, "{:representer=>Module, :policy=>Object}"
  end

#@ DSL tests
  it "importing helpers and constants" do
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

    # Trailblazer::Activity::DSL::Linear::Helper::Constants::My = MyMacros

    strategy = Class.new(Trailblazer::Activity::Path) # DISCUSS: should this be just {Linear::Strategy}?
    strategy.instance_exec do
      step MyHelper()
    end

# FIXME: how are we gonna do this?
    # state.instance_exec do
    #   step My::MyHelper()
    # end

    sequence = strategy.to_h[:sequence]

    assert_process sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task\"
\"Task\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end
end
