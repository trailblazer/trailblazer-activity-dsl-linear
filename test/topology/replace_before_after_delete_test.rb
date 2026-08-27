require "test_helper"

class PrepositionTest < Minitest::Spec
  it "#step accepts {:replace}" do
    {Trailblazer::Activity::Path => []}.each do |activity_class, _|

      my_activity = Class.new(activity_class) do
        step :a
        step :b
        step :c
        step :d, replace: :b, id: :b

        include T.def_steps(:a, :b, :c, :d)
      end

      assert_run my_activity, seq: [:a, :d, :c], terminus: my_activity.to_h[:outputs][:success].signal
    end
  end

  it "#step accepts {:before}" do
    raise
  end

  it "#step accepts {:after}" do

  end

  it "#step accepts {:delete}" do

  end
end
