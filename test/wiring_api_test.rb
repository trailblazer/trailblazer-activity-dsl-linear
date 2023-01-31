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

    assert_equal exception.message, %{No `unknown` output found for :find_model and outputs {:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}}
  end
end
