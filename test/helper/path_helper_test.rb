require "test_helper"

class PathHelperTest < Minitest::Spec
  # it "{Path()} connects to {End.failure} when no {:terminus} given" do

  it "Path(connect_to: Track(:success))" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: Track(:success)) do
        step :c
        step :d
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :e], target_ctx: {seq: [1], b: false}
    # Within the Path, there's only a "success" track.
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :e], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :e], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :c, :d, :e, :f], target_ctx: {seq: [1], b:false, e: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
  end

  it "Path(connect_to: Id(:g))" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: Id(:g)) do
        step :c
        step :d
      end
      step :e
      step :g
      left :f
      step :h

      include T.def_steps(:a, :b, :c, :d, :e, :f, :g, :h)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e, :g, :h]
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :g, :h], target_ctx: {seq: [1], b: false}
    # Within the Path, there's only a "success" track, we never reach {:e} from the Path().
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :g, :h], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d, :g, :h], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :g, :f], target_ctx: {seq: [1], g: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :g, :h], target_ctx: {seq: [1], h: false}
  end

  it "Path(connect_to: Terminus(:success))" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: Terminus(:success)) do
        step :c
        step :d
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false}
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :success, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
  end

  it "Path(connect_to: Terminus(:failure))" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: Terminus(:failure)) do
        step :c
        step :d
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
  end

  it "Path(connect_to: Terminus(:received)), where {:received} is a new terminus" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: Terminus(:received)) do
        step :c
        step :d
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :received, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false}
    assert_run my_activity, terminus: :received, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :received, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
  end

  it "Path(connect_to: false)" do
    my_activity = Class.new(Trailblazer::Activity::Railway) do
      step :a
      step :b, Output(:failure) => Path(connect_to: false) do
        step :c
        step :d, Output(:success) => Terminus(:received), Output(:failure) => Track(:failure)
      end
      step :e
      left :f

      include T.def_steps(:a, :b, :c, :d, :e, :f)
    end

    assert_run my_activity, terminus: :success, seq: [:a, :b, :e]
    assert_run my_activity, terminus: :received, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false}
    assert_run my_activity, terminus: :received, seq: [1, :a, :b, :c, :d], target_ctx: {seq: [1], b: false, c: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :c, :d, :f], target_ctx: {seq: [1], b: false, d: false}
    assert_run my_activity, terminus: :failure, seq: [1, :a, :b, :e, :f], target_ctx: {seq: [1], e: false}
  end
end
