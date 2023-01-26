require "test_helper"

# Test basic options of step:
#   macro vs options
class StepTest < Minitest::Spec
  it "{:id} in {user_options} win over macro options" do
    activity = Class.new(Trailblazer::Activity::Path) do
      step(
        {task: Object, id: "object"},  # macro optios
                      {id: :OBJECT}    # user_options
      )
    end

    assert_equal Trailblazer::Developer.railway(activity), %{[>OBJECT]}
  end

  it "{:replace} in {user_options} win over macro options" do
    activity = Class.new(Trailblazer::Activity::Path) do
      step :params
      step :create_model
      step(
        {task: Object, replace: :params},      # macro optios
                      {replace: :create_model} # user_options
      )
    end

    assert_process_for activity, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*params>
<*params>
 {Trailblazer::Activity::Right} => Object
Object
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

# TODO: remove in 1.2.0.
#@ :override
  it "accepts {:override}" do
    activity = nil

    _, err = capture_io do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step implementing.method(:a), id: :a
        step implementing.method(:b), id: :b
        step(
          {id: :a, task: implementing.method(:c)}, # macro
          override: true
        )
      end
    end
    line_number = __LINE__ - 6

    assert_equal err, %{[Trailblazer] #{File.realpath(__FILE__)}:#{line_number} The :override option is deprecated and will be removed. Please use :replace instead.\n}

    assert_process_for activity.to_h, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    end

  it ":override with inheritance" do
    activity = Class.new(Activity::Railway) do
      step :a#, id: :a
    end

    sub = Class.new(activity) do
      step :a, override: true#, id: :a
    end

    assert_process_for sub.to_h, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    end
end
