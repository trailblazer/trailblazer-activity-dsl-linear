require "test_helper"

class PathHelperTest < Minitest::Spec
  Implementing = T.def_steps(:a, :b, :c, :d, :e, :f, :g)

  it "accepts {:end_task} and {:end_id} and deprecates it" do # TODO: remove in 2.0
    path_end = Activity::End.new(semantic: :roundtrip)
    activity = nil

    _, warning = capture_io do
      activity = Class.new(Activity::Railway) do
        include Implementing

        step :a, Output(:failure) => Path(end_task: End(:roundtrip), end_id: "End.roundtrip") do
          step :f
          step :g
        end
        step :b, Output(:success) => Id(:a)
        step :c, Output(:success) => End(:new)
        fail :d#, Linear.Output(:success) => Linear.End(:new)
      end
    end
    line_no = __LINE__ - 9

    warnings = warning.split("\n") # FIXME: weird hash duplication warnings in JRuby.
    warning = warnings.find { |w| w =~ /end_task/ }

    assert_equal warning, %([Trailblazer] #{File.realpath(__FILE__)}:#{line_no} Using `:end_task` and `:end_id` in Path() is deprecated, use `:terminus` instead. Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-wiring-api-path-end_task-end_id-deprecation)

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

  it "accepts {:terminus}" do
    activity = Class.new(Activity::Railway) do
      include Implementing

      step :a, Output(:failure) => Path(terminus: :roundtrip) do
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
      step :c, Output(:success) => Path(track_color: :green, terminus: :roundtrip) do
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
      step :c, Output(:success) => Path(track_color: :green, terminus: :roundtrip) do
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
      step :c, Output(:success) => Path(terminus: :with_cc, track_color: :green) do
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

  it "{Path()} connects to {End.failure} when no {:terminus} given" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :c, Output(:success) => Path() do
        step :e
      end
      step :f
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_call activity, seq: %{[:c, :e]}, terminus: :failure
  end

  it "{Path()} allows emitting signal via {End()}" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path() do
        step :e
        step :d, Output(:success) => End(:without_cc)
      end
      step :f

      include T.def_steps(:c, :e, :d, :f)
    end

    assert_process_for activity, :success, :without_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:without_cc>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:without_cc>

#<End/:failure>
}

    assert_invoke activity, seq: "[:c, :e, :d]", terminus: :without_cc
  end

  it "{Path()} allows nesting via {Subprocess()}" do
    nested = Class.new(Activity::Railway) do
      step :a
      step :b, Output(:success) => End(:charge)

      include T.def_steps(:a, :b)
    end

    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path() do
        step :e
        step Subprocess(nested), Output(:charge) => End(:with_cc)
        step :d
      end
      step :f

      include T.def_steps(:c, :e, :d, :f)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => <*d>
 {#<Trailblazer::Activity::End semantic=:charge>} => #<End/:with_cc>
<*d>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

    assert_invoke activity, seq: "[:c, :e, :a, :b]", terminus: :with_cc
  end

  it "{Output()} takes precedence over {:terminus} when specified within the {Path()} block" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(terminus: :with_cc) do
        step :e, Output(:success) => Id(:f) # `End(:with_cc)` will get removed in favor of `Id(:f) connection`
      end
      step :f

      include T.def_steps(:c, :e, :f)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}
    assert_invoke activity, seq: "[:c, :e, :f]"
  end

  it "{:connect_to} behaves same as {Output() => Id()} connection" do
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(connect_to: Id(:f)) do
        step :e
      end
      step :f

      include T.def_steps(:c, :e, :f)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*e>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
    assert_invoke activity, seq: "[:c, :e, :f]"
  end

  it "{:wrap_around}" do
    implementing = self.implementing

    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(terminus: :with_cc, track_color: :green) do
      end

      # success:c, success=>green
      # green:End.green

    # we want to connect an Output to the {green} path.
    # The problem is, the path is positioned prior to {:d} in the sequence.
      step :d, Output(:failure) => Track(:green, wrap_around: true)

      include T.def_steps(:c, :d)
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
<*d>
 {Trailblazer::Activity::Left} => #<End/:with_cc>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

  # WrapAround does wrap around, but considers track colors before it wraps.
    activity = Class.new(Activity::Railway) do
      step :c, Output(:success) => Path(terminus: :with_cc, track_color: :green) do
      end

      step :d, Output(:failure) => Track(:green, wrap_around: true) # the option doesn't kick in.

      step :e, magnetic_to: :green # please connect {d} to {e}! and {c} to {e}
    end

    assert_process_for activity, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*e>
<*d>
 {Trailblazer::Activity::Left} => <*e>
 {Trailblazer::Activity::Right} => #<End/:success>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}
  end

  it "allows using a different task builder, etc" do
    implementing = Module.new { extend Trailblazer::Activity::Testing.def_steps(:a, :f, :b) } # circuit interface.

    shared_options = {
      step_interface_builder: Fixtures.method(:circuit_interface_builder)
    }

    path = Trailblazer::Activity.Path(**shared_options) # {shared_options} gets merged into {:normalizer_options} automatically.
    path.step implementing.method(:a), id: :a, path.Output(:success) => path.Path(terminus: :roundtrip) do
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
      normalizers: Linear::Normalizer::Normalizers.new(step: my_normalizer)
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
