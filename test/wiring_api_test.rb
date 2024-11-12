require "test_helper"

# TODO: move all wiring-related tests over here!
class WiringApiTest < Minitest::Spec
  it "accepts {Output() => Id()}" do
    strategy = Class.new(Activity::Path) do
      include Implementing

      step :f
      step :g, Output(:success) => Id(:f)
      step :a
    end

    assert_circuit strategy, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => <*f>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "raises with unknown Output()" do
    exception = assert_raises do
      activity = Class.new(Activity::Path) do
        step :find_model, Output(:unknown) => Track(:success)
      end
    end

    assert_equal CU.inspect(exception.message), %(No `unknown` output found for :find_model and outputs {:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>})
  end

  it "accepts {Output() => End()}" do
    nested_activity = Class.new(Activity::Railway) do
      step :validate,
        Output(:failure) => End(:invalid)
    end

    activity = Class.new(Activity::Railway) do
      step Subprocess(nested_activity).merge(Output(:invalid) => End(:failure)),

        Output(:invalid) => End(:validation_error)
    end

    assert_process activity, :success, :validation_error, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:invalid>} => #<End/:validation_error>
#<End/:success>

#<End/:validation_error>

#<End/:failure>
)
  end
end


###
# Output tuples unit tests
###

class PathWiringApiTest < Minitest::Spec
  it "custom Output(:success) overrides {#step}'s default" do
    activity = Class.new(Activity::Path) do
      step :catch_all
      step :policy, Output(:success) => Id(:catch_all)
    end

    assert_process_for activity, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*catch_all>
<*catch_all>
 {Trailblazer::Activity::Right} => <*policy>
<*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
#<End/:success>
}
  end
end

class RailwayWiringApiTest < Minitest::Spec
  it "custom Output(:success) overrides {#step}'s default" do
    activity = Class.new(Activity::Railway) do
      step :catch_all
      step :policy,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
      pass :model,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
      fail :error,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*catch_all>
<*catch_all>
 {Trailblazer::Activity::Left} => <*error>
 {Trailblazer::Activity::Right} => <*policy>
<*policy>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
<*model>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
<*error>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
#<End/:success>

#<End/:failure>
}
  end
end

class FastTrackWiringApiTest < Minitest::Spec
  it "custom Output(:success) overrides {#step}'s default" do
    activity = Class.new(Activity::FastTrack) do
      step :catch_all
      step :policy,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
      pass :model,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
      fail :error,
        Output(:success) => Id(:catch_all),
        Output(:failure) => Id(:policy)
    end

    assert_process_for activity, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*catch_all>
<*catch_all>
 {Trailblazer::Activity::Left} => <*error>
 {Trailblazer::Activity::Right} => <*policy>
<*policy>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
<*model>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
<*error>
 {Trailblazer::Activity::Left} => <*policy>
 {Trailblazer::Activity::Right} => <*catch_all>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
  end
end
