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
end
