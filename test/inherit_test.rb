require "test_helper"

# Test the {inherit: true} feature.
class InheritTest < Minitest::Spec
  it "per default, it doesn't inherit Output() and friends" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a,
        Output(:success) => Terminus(:winning)
      left :b

      include T.def_steps(:a, :b)
    end

    my_inherit = Class.new(my_activity) do
      step :a, replace: :a
    end

    assert_run my_activity, seq: [:a], terminus: :winning
    assert_run my_activity, seq: [:a, :b], terminus: :failure, target_ctx: {seq: [], a: false}


    assert_run my_inherit, seq: [:a], terminus: :success # we didn't inherit the deviation to {:winning}.
    assert_run my_inherit, seq: [:a, :b], terminus: :failure, target_ctx: {seq: [], a: false}
  end

  it "with {inherit: true}, it inherits Output()" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a,
        Output(:success) => Terminus(:winning)
      left :b

      include T.def_steps(:a, :b)
    end

    my_inherit = Class.new(my_activity) do
      step :a, replace: :a, inherit: true
    end

    assert_run my_activity, seq: [:a], terminus: :winning
    assert_run my_activity, seq: [:a, :b], terminus: :failure, target_ctx: {seq: [], a: false}


    assert_run my_inherit, seq: [:a], terminus: :winning
    assert_run my_inherit, seq: [:a, :b], terminus: :failure, target_ctx: {seq: [], a: false}
  end
end
