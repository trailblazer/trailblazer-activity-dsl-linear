require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Linear::Strategy)

    assert_equal strategy.to_h[:sequence].inspect, %{[[nil, #<Trailblazer::Activity::Start semantic=:default>, [], {:id=>"Start.default"}]]}

    assert_circuit strategy.to_h, %{
#<Start/:default>
}
  end
end
