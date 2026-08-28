require "test_helper"

class PatchTest < Minitest::Spec
  it "Patch" do
    my_nested_nested = Class.new(Trailblazer::Activity::Path) do
      step :c
      include T.def_steps(:c)
    end

    my_nested = Class.new(Trailblazer::Activity::Path) do
      step :b
      step Subprocess(my_nested_nested), id: :after_b
      include T.def_steps(:b)
    end

    my_activity = Class.new(Trailblazer::Activity::Path) do
      step :a
      step Subprocess(my_nested), id: :after_a
      include T.def_steps(:a)
    end


    my_block = ->(*) { step T.def_steps(:d).method(:d), before: :c, id: :d }

    my_patched_activity = Trailblazer::Activity::DSL::Feature::Patch.(my_activity, [:after_a, :after_b], my_block)

    assert_run my_activity, seq: [:a, :b, :c], terminus: my_activity.to_h[:outputs][:success].signal
    assert_run my_patched_activity, seq: [:a, :b, :d, :c], terminus: my_activity.to_h[:outputs][:success].signal
  end


  it "retains wirings in patched activity" do
    advance = Class.new(Trailblazer::Activity::Railway) do
      step :g,
        Output(:failure) => Terminus(:g_failure)
      step :f

      include T.def_steps(:g, :f)
    end

    controller = Class.new(Trailblazer::Activity::Railway) do
      step Subprocess(advance),
        id: :advance,
        Output(:g_failure) => Terminus(:g_failure)
      step :d

      include T.def_steps(:d)
    end

    my_controller = Class.new(Trailblazer::Activity::Railway) do
      step :c
      step Subprocess(controller, patch: { [:advance] => -> { step T.def_steps(:h).method(:h), id: :h } }),
        id: :controller,
        Output(:g_failure) => Terminus(:g_failure)

      include T.def_steps(:c)
    end

    assert_run controller, terminus: controller.to_h[:outputs][:g_failure].signal, seq: [:g], target_ctx: {seq: [], g: false}
    assert_run my_controller, terminus: my_controller.to_h[:outputs][:g_failure].signal, seq: [:c, :g, :h], target_ctx: {seq: [], g: false}
  end
end
