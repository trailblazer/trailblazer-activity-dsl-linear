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

#@ IDs in macro options
  it "allows :instance_methods with circuit interface" do
    nested_activity = Class.new(Activity::Path) do
      step task: :c
      include T.def_tasks(:c)
    end

    activity = Class.new(Activity::Path) do
      step task: :a
      step Subprocess(nested_activity)
      step task: :b
      include T.def_tasks(:a, :b)
    end

    assert_invoke activity, seq: %{[:a, :c, :b]}
  end

  # ID for {task: <task>}
  # TODO: this should also test ID for {step <task>}
  it "ID is {:task} unless specified" do
    activity = Class.new(Activity::Path) do
      include implementing = T.def_tasks(:a, :b, :d, :f)

      step task: :a
      step task: :b, id: :B
      step task: method(:raise)
      step task: implementing.method(:d), id: :d
      step({task: implementing.method(:f), id: :f}, replace: method(:raise))
    end

    assert_equal Trailblazer::Developer.railway(activity), %{[>a,>B,>f,>d]}
    assert_invoke activity, seq: %{[:a, :b, :f, :d]}
  end

# TODO: remove :override tests in 1.2.0.
#@ :override
  # TODO: remove in 1.2.0.
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

  # TODO: remove in 1.2.0.
  it "{:override} with inheritance" do
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

class StepInheritOptionTest < Minitest::Spec
  let(:create_activity) do
    Class.new(Trailblazer::Activity::Railway) do
      step :create_model
      step :validate
      step :save, id: :save_the_world

      include T.def_steps(:create_model, :validate, :save)
    end
  end

  it "{:replace} and {:inherit} automatically use {:id} from replaced step" do
    activity = Class.new(create_activity) do
      include T.def_steps(:find_model)

      step :find_model, replace: :create_model, inherit: true  #=> id: :create_mode
    end

    assert_equal Trailblazer::Developer.railway(activity), %{[>create_model,>validate,>save_the_world]}
    assert_invoke activity, seq: %{[:find_model, :validate, :save]}
  end

  it "{:id} is also infered from {:replace} if {:inherit} a value other than {true}" do
    activity = Class.new(create_activity) do
      include T.def_steps(:find_model)

      step :find_model, replace: :create_model, inherit: [1,2,3]  #=> id: :create_mode
    end

    assert_equal Trailblazer::Developer.railway(activity), %{[>create_model,>validate,>save_the_world]}
    assert_invoke activity, seq: %{[:find_model, :validate, :save]}
  end

  it "{:replace} and {:inherit} allow explicit {:id}, but it has to be an existing so {:inherit} is happy" do
    activity = Class.new(create_activity) do
      include T.def_steps(:find_model)

      step :find_model, replace: :create_model, inherit: true,
        id: :create_model # ID has to be identical to {:replace} so inherit logic can find.
    end

    assert_equal Trailblazer::Developer.railway(activity), %{[>create_model,>validate,>save_the_world]}
    assert_invoke activity, seq: %{[:find_model, :validate, :save]}
  end
end
