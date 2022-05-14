require "test_helper"

class PathHelperTest < Minitest::Spec
  Implementing = T.def_steps(:a, :b, :c, :d, :e, :f, :g)

  it "accepts {:end_task} and {:end_id}" do
    path_end = Activity::End.new(semantic: :roundtrip)

    activity = Class.new(Activity::Railway) do
      include Implementing

      step :a, Output(:failure) => Path(end_task: path_end, end_id: "End.roundtrip") do
        step :f
        step :g
      end
      step :b, Output(:success) => Id(:a)
      step :c, Output(:success) => End(:new)
      fail :d#, Linear.Output(:success) => Linear.End(:new)
    end

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => <*f>
 {Trailblazer::Activity::Right} => <*b>
<*f>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
<*b>
 {Trailblazer::Activity::Left} => <*d>
 {Trailblazer::Activity::Right} => <*a>
<*c>
 {Trailblazer::Activity::Left} => <*d>
 {Trailblazer::Activity::Right} => #<End/:new>
<*d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:new>

#<End/:roundtrip>

#<End/:failure>
}
  end

  it "allows inserting steps onto an empty Path()" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :a
      step :c, Output(:success) => Path(track_color: :green, end_id: "End.roundtrip", end_task: End(:roundtrip)) do
      end
      step :e
    #@ Add {:f} to empty path.
      step :f, magnetic_to: :green, Output(:success) => Track(:green) # FIXME: we obviously have two outputs here.
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*f>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<End/:success>

#<End/:roundtrip>

#<End/:failure>
}
  end

  it "allows inserting steps onto an existing Path()" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :a
      step :c, Output(:success) => Path(track_color: :green, end_id: "End.roundtrip", end_task: End(:roundtrip)) do
        step :d  # look for the next {magnetic_to: :green} occurrence.
      end
      step :e
      step :f, before: :d, magnetic_to: :green, Output(:success) => Track(:green)
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:roundtrip>

#<End/:failure>
}
  end



  it "{Path()} without block just adds one {End.green} terminus, but you can connect an earlier step {:a} to the beginning of the path" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :a, Output(:success) => Track(:green)
      step :c, Output(:success) => Path(end_id: "End.cc", end_task: End(:with_cc), track_color: :green) do
      end

      # step :d, Output(:failure) => Track(:green, wrap_around: true)
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}
  end

  it "{Path()} allows connecting to the outer step using {Output() => Id()}" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :c, Output(:success) => Path() do
        step :d, Output(:success) => Id(:f)
        step :e
      end
      step :f
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => <*f>
<*e>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_call activity, seq: %{[:c, :d, :f]}
  end


  it "allows using a different task builder, etc" do
    implementing = Module.new { extend Activity::Testing.def_steps(:a, :f, :b) } # circuit interface.

    shared_options = {
      step_interface_builder: Fixtures.method(:circuit_interface_builder)
    }

    path = Activity.Path(**shared_options) # {shared_options} gets merged into {:normalizer_options} automatically.
    path.step implementing.method(:a), id: :a, path.Output(:success) => path.Path(end_task: Activity::End.new(semantic: :roundtrip), end_id: "End.roundtrip") do
      step implementing.method(:f), id: :f
    end
    path.step implementing.method(:b), id: :b, path.Output(:success) => path.Id(:a)

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<Fixtures::CircuitInterface:0x @step=#<Method: #<Module:0x>.a>>
#<End/:success>

#<End/:roundtrip>
}

    assert_call path, a: false, :seq=>"[:a, :f]", terminus: :roundtrip
  end

  it "allows using different normalizers" do
    skip "we need a mechanism for generically extending normalizers"
  #@ We inject an altered normalizer that prepends every ID with "My ".
    class ComputeId
      def self.call(ctx, id:, **)
        ctx[:id] = "My #{id}"
      end
    end

    my_normalizer = Activity::TaskWrap::Pipeline.prepend(
      Activity::Path::DSL.Normalizer(),
      "activity.normalize_override",
      {
        "my.compute_id"  => Linear::Normalizer.Task(ComputeId),
      }
    )

    shared_options = {
      # step_interface_builder: Fixtures.method(:circuit_interface_builder)
      normalizers: Linear::State::Normalizer.new(step: my_normalizer)
    }

    path = Activity.Path(**shared_options)
    path.include Implementing
    path.step :a, path.Output(:success) => path.Path(end_task: Activity::End.new(semantic: :roundtrip), end_id: "End.roundtrip") do
      step :f
    end

    graph = Activity::Introspect.Graph(path)
    assert_equal graph.find("My a").task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
    assert_equal graph.find("My f").task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=f>}

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:roundtrip>
#<End/:success>

#<End/:roundtrip>
}

    assert_call path, :seq=>"[:a, :f]", terminus: :roundtrip
  end
end
