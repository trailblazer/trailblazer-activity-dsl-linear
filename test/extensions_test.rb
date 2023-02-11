require "test_helper"

# @test {:extensions} option
# @tests Extensions are kept in row.data[:extensions]
class ExtensionsTest < Minitest::Spec
  def add_1(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  let(:merge) do
    [
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"]
    ]
  end

  it "accepts {:extensions} and exposes it in {row.data}" do
    add_1_extension = Trailblazer::Activity::TaskWrap::Extension.WrapStatic(*merge)

    activity = Class.new(Activity::Path) do
      step :model,
        extensions: [add_1_extension]
      step :save

      include T.def_steps(:model, :save)
    end

    assert_process_for activity, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*model>
<*model>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    assert_invoke activity, seq: "[1, :model, :save]"

    #@ we can access extensions via the Sequence:
    assert_equal activity.to_h[:sequence][0].data[:extensions], nil #[] # FIXME: this should always be an array!
    assert_equal activity.to_h[:sequence][1].data[:extensions], [add_1_extension]
  end

  it "accepts {:extensions} along with {:input} and other additional extensions" do
    add_1_extension = Trailblazer::Activity::TaskWrap::Extension.WrapStatic(*merge)

    activity = Class.new(Activity::Path) do
      # :extensions doesn't overwrite :input and vice-versa!
      step :model,
        extensions: [add_1_extension],
        input:      ->(ctx, *) { {seq: ctx[:seq] += [:input]} }
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :input, :model, :save]"
  end
end
