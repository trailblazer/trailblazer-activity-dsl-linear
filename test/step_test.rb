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
end
