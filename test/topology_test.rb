require "test_helper"

class TopologyTest < Minitest::Spec
  # DISCUSS: we only need this because we're not using the Output-tuple layer here that computes a :wirings hash for us.
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
      # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
    }
  end

  it "#to_h" do

  end


  it "#step accepts {:task}" do

  end

  it "{:adds_insertion_args}" do

  end

  it "{:exec_context} is defaulted" do

  end

  it "#step computes {:id} for a step" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step :b,# i am a terminus.
        exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after]
    end

    assert_equal my_topology.to_h[:circuit].nodes[:b].id, :b
  end

  it "#step accepts {:id}" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step :b,# i am a terminus.
        id: :terminus_success, exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after]
    end

    assert_equal my_topology.to_h[:circuit].nodes[:terminus_success].id, :terminus_success
  end

  it "#step raises error with {:id} already used" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step :b,# i am a terminus.
        id: :b, exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :failure,
        adds_insertion_args: [:after]
    end

    assert_raises Trailblazer::Circuit::Adds::IllegalIdError do
      my_topology.step :B, id: :b, exec_context: nil, wirings: {}
    end
  end

  it "#step accepts {:magnetic_to}" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
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
      step task: T.def_tasks(:a).method(:a),
        id: :a, #exec_context: new,
        wirings: TopologyTest.FIXME___DEFAULT_WIRINGS.merge(Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:failure)),
        adds_insertion_args: [:before]

      include T.def_steps(:b, :c)
    end

    pp my_topology.to_h[:circuit]

    assert_run my_topology.to_h[:circuit], seq: [:a, :c], terminus: Trailblazer::Activity::Right
    assert_run my_topology.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right, target_ctx: {a: Trailblazer::Activity::Left, seq: []}
  end

  it "#step accepts {:adds_for_sequence} where we can add additional steps" do
    raise
  end

  it "provides #step" do
    success = nil
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"task_wrap.End.success", magnetic_to: :success,
        adds_insertion_args: [:after],
        wirings: {Trailblazer::Activity::Output.new(success, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}

      step :a, id: :a, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a)
    end

    # pp my_topology.config.sequence
    # pp my_topology.to_h[:circuit]

    my_topology_node = Trailblazer::Circuit::Node[:create, my_topology.to_h[:circuit], Trailblazer::Circuit::Processor]

    pp my_topology_node

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      my_topology_node,
      {target_ctx: {seq: []}},
      # {application_ctx: },
      {},
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_run my_topology_node, node: true,
      seq: [:a],
      terminus: success,
      use_application_ctx: false # FIXME
  end

  it "inheritance doesn't bleed into parents" do
    success = nil
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"task_wrap.End.success",
         wirings: {Trailblazer::Activity::Output.new(success, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        adds_insertion_args: [:after]

      step :a, id: :a, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a)
    end

    my_child_activity = Class.new(my_topology)
    my_child_activity_with_b_step = Class.new(my_topology) do
      step :b, id: :b, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:b)
    end


    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: my_topology.to_h[:circuit].nodes.values.last.task, terminus: success
    assert_run my_child_activity.to_h[:circuit], seq: [:a], terminus: success

    assert_run my_child_activity_with_b_step.to_h[:circuit], seq: [:a, :b], terminus: success
  end

  it "we can compile the Circuit only once" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      step :a, id: :a, exec_context: nil, adds_insertion_args: [:before], wirings: {}
      step :b, id: :b, exec_context: nil, adds_insertion_args: [:before], wirings: TopologyTest.FIXME___DEFAULT_WIRINGS
    end

    class MyConfig < Struct.new(:config, :activity_count)
      def activity=(value)
        self.activity_count += 1

        config.activity = value
      end

      def activity; config.activity end

      def sequence; config.sequence end
      def sequence=(value); config.sequence=(value) end
      def normalizer; config.normalizer end
    end

    require "trailblazer/activity/finalize"
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
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

    assert_equal my_topology.config.activity_count, 1

    # my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
    #   wiring do
    #     step :a
    #     step :b
    #   end # => this would allow compiling once
    # end
  end
end
