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

#@ {:inhert} implements inheriting {:extensions}
  let(:ext) do
    merge = [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"]
    ext   = Trailblazer::Activity::TaskWrap::Extension.WrapStatic(merge)
  end

  it "{inherit: true} copies {:extensions}" do
    _ext = ext

    activity = Class.new(Activity::Path) do
      step :a, extensions: [_ext]
      step :b                     # no {:extensions}
      include T.def_steps(:a, :b)
    end

    sub = Class.new(activity) do
      step :c, inherit: true, replace: :a # this should also "inherit" the taskWrap configs for this task.
      step :d, inherit: true, replace: :b, extensions: [_ext] # we want to "override" the original {:extensions}
      include T.def_steps(:c, :d)
    end

    assert_invoke activity, seq: "[1, :a, :b]"
    assert_invoke sub,      seq: "[1, :c, 1, :d]"
  end

#@ inheriting connections
  #@ nest a FastTrack in a Railway.
  it "{inherit: true} automatically reduces outputs fitting the new, overriding activity" do
    fast_track = Class.new(Activity::FastTrack)
    railway    = Class.new(Activity::Railway)

    activity = Class.new(Activity::Railway) do
      step Subprocess(fast_track), id: :fast_track
    end

    # We're replacing FastTrack with Railway.
    sub_activity = Class.new(activity) do
      step Subprocess(railway), inherit: true, replace: :fast_track
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  #@ Nest a FastTrack in a Railway, but both activities have a new terminus {:invalid}
  it "{inherit: true} automatically reduces outputs fitting the new, overriding activity, part II" do
    fast_track = Class.new(Activity::FastTrack) do terminus :invalid  end
    railway    = Class.new(Activity::Railway)   do terminus :invalid  end

    activity = Class.new(Activity::FastTrack) do
      terminus :invalid
      step Subprocess(fast_track, strict: true), id: :fast_track # all 5 outputs are wired.
    end

    # We're replacing FastTrack with Railway.
    # Since we're using {strict: true}, success, failure *and invalid* are connected.
    strict_sub_activity = Class.new(activity) do
      step Subprocess(railway, strict: true), inherit: true, replace: :fast_track # 3 outputs are wired.
    end

    sub_activity = Class.new(activity) do
      step Subprocess(railway), inherit: true, replace: :fast_track               # 2 outputs are wired.
    end

    assert_process_for activity, :success, :invalid, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:invalid>} => #<End/:invalid>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
#<End/:success>

#<End/:invalid>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

    assert_process_for strict_sub_activity, :success, :invalid, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:invalid>} => #<End/:invalid>
#<End/:success>

#<End/:invalid>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

    assert_process_for sub_activity, :success, :invalid, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<End/:invalid>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
  end

  it "{inherit: true} filters out unsupported semantics automatically (non strict)" do
    nested = Class.new(Activity::Railway) do
      terminus :invalid
    end

    activity = Class.new(Activity::Railway) do
      step Subprocess(nested),
        id: :validate,
        Output(:failure) => Track(:success),
        Output(:invalid) => Track(:failure),
        Output(:success) => End(:ok) # this is the only inherited connection.
    end

    sub_activity = Class.new(activity) do
      step Subprocess(Activity::Path),
        inherit:  true,
        replace:  :validate
    end

    assert_process_for sub_activity, :success, :ok, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => Trailblazer::Activity::Path
Trailblazer::Activity::Path
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:ok>
#<End/:success>

#<End/:ok>

#<End/:failure>
}
  end

  it "{inherit: true} copies custom connections from step" do
    activity = Class.new(Activity::Railway) do
      step :model,
        Output(:failure)         => Track(:success),
        Output(Module, :invalid) => Track(:failure)  # custom "terminus" and connection.
      include T.def_steps(:model)
    end

    sub_activity = Class.new(activity) do
      step :create_model, inherit: true, replace: :model # just inherit {:connections}
      include T.def_steps(:create_model)
    end
    # TODO
      # step :d, inherit: true, replace: :b, Output(:success) => Id(:model) # add even more to {:connections}

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*model>
<*model>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Module} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Module} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
  end

  it "{inherit: true} allows adding custom connections while inheriting custom connections" do
    activity = Class.new(Activity::Railway) do
      step :model,
        Output(:failure)         => Track(:success),
        Output(Module, :invalid) => Track(:failure)  # custom "terminus" and connection.
      include T.def_steps(:model)
    end

    sub_activity = Class.new(activity) do
      step :authorize, before: :model
      step :format
      step :create_model, inherit: true, replace: :model,
        Output(:success) => Id(:authorize), # new connection
        Output(:failure) => Id(:format)     # overriding failure=>success connection from above

      include T.def_steps(:create_model, :authorize)
    end

    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*authorize>
<*authorize>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => <*format>
 {Trailblazer::Activity::Right} => <*authorize>
 {Module} => #<End/:failure>
<*format>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end


  it "{inherit: true} copies custom connections from nested Subprocess()" do
    nested = Class.new(Activity::Railway) do
      terminus :invalid
    end

    activity = Class.new(Activity::Railway) do
      step Subprocess(nested),
        id: :model,
        Output(:failure) => Track(:success),
        Output(:invalid) => Track(:failure)  # custom "terminus" and connection.
    end

    new_nested = nested = Class.new(Activity::Railway) do
      terminus :invalid
      terminus :ok
    end

    sub_activity = Class.new(activity) do
      step Subprocess(new_nested),
        replace: :model,
        inherit: true # we don't add custom Outputs here.
    end

    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:invalid>} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

    # Add custom Output to inherited on Subprocess().
    sub_activity = Class.new(activity) do
      step :authorize, before: :model
      step :format
      step Subprocess(new_nested), inherit: true, replace: :model,
        Output(:success) => Id(:authorize), # new connection
        Output(:invalid) => Id(:format)     # overriding failure=>success connection from above

      include T.def_steps(:create_model, :authorize)
    end

    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*authorize>
<*authorize>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => <*format>
 {#<Trailblazer::Activity::End semantic=:success>} => <*authorize>
 {#<Trailblazer::Activity::End semantic=:invalid>} => <*format>
<*format>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "inherits connections if {inherit: true}" do
    fast_track = Class.new(Activity::FastTrack)
    railway    = Class.new(Activity::Railway)

    activity = Class.new(Activity::Railway) do
      step :model,
        Output(:failure)         => Track(:success),
        Output(Module, :invalid) => Track(:failure)

    #@ additional outputs, 3 in total, as they got reduced to Railway
      step Subprocess(fast_track), id: :fast_track

      step :b,
        Output(Object, :invalid) => Id(:model)

      include T.def_steps(:model, :b)
    end

    sub_activity = Class.new(activity) do
      step Subprocess(railway), inherit: true, replace: :fast_track

      step :c, inherit: true, replace: :model # just inherit {:connections}
      # step :d, inherit: true, replace: :b, Output(:success) => Id(:model) # add even more to {:connections}
      include T.def_steps(:c, :d)
    end

    # Note: The nested FastTrack has three outputs (not five).
    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*model>
<*model>
 {Trailblazer::Activity::Left} => #<Class:0x>
 {Trailblazer::Activity::Right} => #<Class:0x>
 {Module} => #<End/:failure>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Object} => <*model>
#<End/:success>

#<End/:failure>
}

    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<Class:0x>
 {Trailblazer::Activity::Right} => #<Class:0x>
 {Module} => #<End/:failure>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Object} => <*c>
#<End/:success>

#<End/:failure>
}

    # assert_invoke activity, seq: "[:model, :b]"
    # assert_invoke sub,      seq: "[:c, :d]"
  end

  it "{fast_track: true} is inherited properly" do
    activity = Class.new(Activity::FastTrack) do
      step :model, pass_fast: true, fail_fast: true
    end

    fast_track = Class.new(Activity::FastTrack) do
      step :model, pass_fast: true, fail_fast: true

      include T.def_steps(:model)
    end

    sub_activity = Class.new(activity) do
      step Subprocess(fast_track), inherit: true, replace: :model
    end

    assert_process_for sub_activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

    assert_invoke sub_activity, model: true,  seq: "[:model]", terminus: :pass_fast
    assert_invoke sub_activity, model: false, seq: "[:model]", terminus: :fail_fast
  end

  it "does not inherit connections if {:inherit} is anything other than true" do
    activity = Class.new(Activity::Railway) do
      step :model,
        Output(:failure) => Track(:success),
        In() => {:create_model => :user}
    end

    sub_activity = Class.new(activity) do
      step :create_model, inherit: 1, replace: :model
      include T.def_steps(:create_model)
    end

    # no inherited connectors:
    assert_process_for sub_activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    # no In filter applied:
    assert_invoke sub_activity, create_model: false, seq: "[:create_model]", terminus: :failure
  end
end


# inheriting:
# should only inherit "custom connections", and throw away the canonical_outputs hash

# step :a
#   normalizer.default/Subprocess
#   Output(Left, :failure) => Track(:failure)
#   Output(:failure) => Track(:invalid)
#   Output(Leftuslefty, :failure) => Track(:failure)



# This shouldn't be possible:
# step Subprocess(fast_track), id: :fast_track, Output(Module, :invalid) => Track(:failure)

