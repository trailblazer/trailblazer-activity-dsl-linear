require "test_helper"

class TopologyTest < Minitest::Spec
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
      # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
    }
  end


  it "#step accepts {:task}" do

  end

  it "{:adds_insertion_args}" do

  end

  it "#step accepts {:magnetic_to}" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :b,# i am a terminus.
        id: :b, exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :failure,
        adds_insertion_args: [:after]

      step :c, # i am a terminus.
        id: :c, exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        # magnetic_to: :success,
        adds_insertion_args: [:after]

      # this is the first step.
      step task: T.def_tasks(:a).method(:a), # FIXME: we cannot return signals from steps, yet!
        id: :a, exec_context: new,
        wirings: TopologyTest.FIXME___DEFAULT_WIRINGS.merge(Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:failure)),
        adds_insertion_args: [:before]

      include T.def_steps(:b, :c)
    end

    assert_run my_topology.config.circuit, seq: [:a, :c], terminus: Trailblazer::Activity::Right
    assert_run my_topology.config.circuit, seq: [:a, :b], terminus: Trailblazer::Activity::Right, flow_options: {application_ctx: {a: Trailblazer::Activity::Left, seq: []}}
  end

  it "provides #step" do
    success = nil
    my_topology = Class.new(Trailblazer::Activity) do
      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"task_wrap.End.success", magnetic_to: :success,
        adds_insertion_args: [:after],
        wirings: {Trailblazer::Activity::Output.new(success, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}

      step :a, id: :a, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a)
    end

    # pp my_topology.config.sequence
    # pp my_topology.config.circuit

    my_topology_node = Trailblazer::Circuit::Node[:create, my_topology.config.circuit, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      my_topology_node,
      {},
      {application_ctx: {seq: []}},
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_run my_topology_node, node: true,
      seq: [:a],
      terminus: success
  end

  it "inheritance doesn't bleed into parents" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :a, id: :a, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a)
    end

    my_child_activity = Class.new(my_topology)
    my_child_activity_with_b_step = Class.new(my_topology) do
      step :b, id: :b, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:b)
    end


    assert_run my_topology.config.circuit, seq: [:a], terminus: my_topology.config.circuit.nodes.values.last.task
    assert_run my_child_activity.config.circuit, seq: [:a], terminus: my_child_activity.config.circuit.nodes.values.last.task
    pp my_child_activity_with_b_step.config.circuit.flow_map
    assert_run my_child_activity_with_b_step.config.circuit, seq: [:a], terminus: my_child_activity_with_b_step.config.circuit.nodes.values.last.task
  end

  it "we can compile the Circuit only once" do
    my_topology = Class.new(Trailblazer::Activity) do
      step :a, id: :a, exec_context: nil, adds_insertion_args: [:before], wirings: {}
      step :b, id: :b, exec_context: nil, adds_insertion_args: [:before], wirings: TopologyTest.FIXME___DEFAULT_WIRINGS
    end

    class MyConfig < Struct.new(:config, :circuit_count)
      def circuit=(value)
        self.circuit_count += 1

        config.circuit = value
      end

      def sequence; config.sequence end
      def sequence=(value); config.sequence=(value) end
      def outputs=(value); config.outputs=(value) end
      def normalizer; config.normalizer end
    end

    require "trailblazer/activity/finalize"
    my_topology = Class.new(Trailblazer::Activity) do
      # DISCUSS: is extend the only way? can we use something like another pipe?
      extend Trailblazer::Activity::Finalize # DISCUSS: Feature::Finalize, or where would that go?

      @my_config = MyConfig.new(config, 0)
      def self.config
        @my_config
      end

      step :a, id: :a, exec_context: nil, adds_insertion_args: [:before], wirings: {}
      step :b, id: :b, exec_context: nil, adds_insertion_args: [:before], wirings: TopologyTest.FIXME___DEFAULT_WIRINGS
    end

    my_topology.finalize

    assert_equal my_topology.config.circuit_count, 1

    # my_topology = Class.new(Trailblazer::Activity) do
    #   wiring do
    #     step :a
    #     step :b
    #   end # => this would allow compiling once
    # end
  end
end
