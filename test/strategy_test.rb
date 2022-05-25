require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Linear::Strategy)

    assert_equal strategy.to_h[:sequence].inspect, %{[[nil, #<Trailblazer::Activity::Start semantic=:default>, [], {:id=>"Start.default"}]]}

    assert_circuit strategy.to_h, %{
#<Start/:default>
}
  end

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
end
