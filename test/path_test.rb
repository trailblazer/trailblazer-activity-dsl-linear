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
    path = Activity.Path() do
      row = Activity::DSL::Linear::Sequence.create_row(
        magnetic_to: :success,
        task: Implementing.method(:g),
        wirings: [Trailblazer::Activity::DSL::Linear::Sequence::Search.Forward(Activity.Output(Activity::Right, :success), :success)]
      )

      step :f,
        adds: [
          {
            row:    row,
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
    path = Activity.Path() do
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
    path = Activity.Path() do
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
    path = Activity.Path() do
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
    path = Activity.Path() do
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
      path = Activity.Path(track_name: :green) do
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
      path = Activity.Path(end_task: Activity::End.new(semantic: :winning), end_id: "End.winner") do
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

    it "accepts {:termini} and overrides Path's termini" do
      path = Activity.Path(
        termini: [
                  [Activity::End.new(semantic: :success), id: "End.success",  magnetic_to: :success, append_to: "Start.default"],
                  [Activity::End.new(semantic: :winning), id: "End.winner",   magnetic_to: :winner],
                ]
      ) do
        step :f
        step :g, Output(Object, :failure) => Track(:winner)
      end

      assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Object} => #<End/:winning>
#<End/:success>

#<End/:winning>
}
    end

    # @generic strategy test
    it "copies (extended) normalizers from original {Activity::Path} and thereby allows i/o" do
      path = Activity.Path() do
        step :model, Inject() => {:id => ->(*) { 1 }}

        def model(ctx, id:, seq:, **)
          seq << id
        end
      end

      assert_invoke path, seq: %{[1]}
    end
  end
end
