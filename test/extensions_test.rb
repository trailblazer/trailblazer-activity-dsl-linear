require "test_helper"

# @test {:extensions} option
# @tests Extensions are kept in row.data[:extensions]
class ExtensionsTest < Minitest::Spec
  def add_1(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  let(:prepend_1_extension) do
    Trailblazer::Activity::TaskWrap::Extension.WrapStatic(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"]
    )
  end

  let(:suffix_1_extension) do
    Trailblazer::Activity::TaskWrap::Extension.WrapStatic(
      [method(:add_1), id: "suffix_add_1", append: "task_wrap.call_task"]
    )
  end

  it "accepts {:extensions} along with {In()} and other additional extensions" do
    add_1_extension = prepend_1_extension

    activity = Class.new(Activity::Path) do
      # :extensions doesn't overwrite In() and vice-versa!
      step :model,
        extensions: [add_1_extension],
        In() =>     ->(ctx, *) { {seq: ctx[:seq] += [:input]} }
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :input, :model, :save]"
  end

  it "accepts Extension()" do
    test = self

    activity = Class.new(Activity::Path) do
      step :model,
        Extension() => test.suffix_1_extension,
        Extension() => test.prepend_1_extension
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :model, 1, :save]"
  end

  it "accepts Extension(generic: true) which is not inherited with {inherit: true}" do
    test = self

    activity = Class.new(Activity::Path) do
      step :model,
        Extension(is_generic: true) => test.suffix_1_extension, # *not* inherited to {sub_activity}.
        Extension()                 => test.prepend_1_extension
      step :save

      include T.def_steps(:model, :save)
    end

    sub_activity = Class.new(activity) do
      step :create_model,
        inherit: true, replace: :model

      include T.def_steps(:create_model)
    end

    assert_invoke activity, seq: "[1, :model, 1, :save]"
    assert_invoke sub_activity, seq: "[1, :create_model, :save]"
    # assert_equal activity.to_h[:sequence][1].data[:extensions][0], %{}
  end
end
