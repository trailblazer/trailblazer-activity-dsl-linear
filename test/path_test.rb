require "test_helper"

class PathTest < Minitest::Spec
  Implementing = T.def_steps(:a, :b, :c, :d, :f, :g)

  it "empty Path subclass" do
    path = Class.new(Activity::Path) do
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_call path
  end

  it "Path exposes {#step} and {#call}" do
    path = Class.new(Activity::Path) do
      include Implementing
      step :a
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_call path, seq: "[:a]"
  end


  it "accepts {:adds}" do
    path = Activity::Path() do
      step :f,
        adds: [
          {
            row:    [:success, Implementing.method(:g), [Trailblazer::Activity::DSL::Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {}],
            insert: [Activity::Adds::Insert.method(:Prepend), :f]
          }
        ]
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: PathTest::Implementing.g>
#<Method: PathTest::Implementing.g>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:before}" do
    path = Activity::Path() do
      step :f
      step :a, before: :f
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:after}" do
    path = Activity::Path() do
      step :f
      step :b
      step :a, after: :f
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:replace}" do
    path = Activity::Path() do
      step :f
      step :a, replace: :f, id: :a
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "accepts {:delete}" do
    path = Activity::Path() do
      step :f
      step nil, delete: :f#, id: :a
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  describe "Activity.Path() builder" do
    it "accepts {:track_name}" do
      path = Activity::Path(track_name: :green) do
        include Implementing
        step :f
        step :g

        step :a, magnetic_to: :success # won't be connected
        step :b, magnetic_to: :green
      end

      assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => <*b>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end

    it "accepts {:end_task}" do
      path = Activity::Path(end_task: Activity::End.new(semantic: :winning), end_id: "End.winner") do
        step :f
        step :g
      end

      assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => #<End/:winning>
#<End/:winning>
}
    end
  end
end
