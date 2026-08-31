require "test_helper"

class PathHelperTest < Minitest::Spec
  # it "{Path()} connects to {End.failure} when no {:terminus} given" do

  it "Path(terminus: :success)" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(terminus: :success) do
        step :c
        step :d
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :success, seq: [:a, :b, :c, :d], target_ctx: {seq: [1], b: false}
  end
end
