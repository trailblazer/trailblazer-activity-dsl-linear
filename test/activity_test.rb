require "test_helper"

class ActivityTest < Minitest::Spec
  it "allows inheritance" do
    implementing = self.implementing

    activity = Class.new(Activity::Path) do
      step implementing.method(:a), id: :a
      step implementing.method(:b), id: :b
    end

    sub_activity = Class.new(activity) do
      step implementing.method(:c), id: :c
      step implementing.method(:d), id: :d
    end

    process = activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = sub_activity.to_h[:process]

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  # Path() with macaroni
  # merge!
  # inheritance
  # :step_method
  # macaroni
end
