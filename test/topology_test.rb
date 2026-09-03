require "test_helper"

class TopologyTest < Minitest::Spec
  # DISCUSS: we only need this because we're not using the Output-tuple layer here that computes a :wirings hash for us.
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
      # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
    }
  end

  it "#to_h with empty Topology" do
    skip "there is no use case for this to be working"
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
    end

    assert_equal my_topology.to_h.keys, [:activity, :outputs]
  end

  it "#to_h" do

  end

  it "#step accepts {:task}" do

  end

  it "{:adds_insertion_args}" do

  end

  it "{:exec_context} is defaulted" do

  end

  it "#step can add the same callable multiple times" do

  end

  it "we can access {:block_argument} if given" do
    my_block = ->(*) { snippet }

    my_activity = Class.new(Trailblazer::Activity::Path) do
      step :a,
        Trailblazer::Activity::DSL::Feature::Data.Variable() => [:block_arg],
        &my_block
    end

    assert_equal my_activity.config.builder.sequence.nodes[:a].data[:block_arg], my_block
  end

  it "#step computes {:id} for a step" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step :b,# i am a terminus.
        exec_context: T.def_steps(:b),
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after]
    end

    # nothing returned when querying non-existant ID.
    assert_nil my_topology.to_h[:circuit].nodes[:bla]

    # we simply run the {:b} task to see if it's {#b} :)
    assert_run my_topology.to_h[:circuit].nodes[:b].task, seq: [:b], terminus: Trailblazer::Activity::Right
  end

  it "#step accepts {:id}" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step :b,# i am a terminus.
        exec_context: T.def_steps(:b),
        id: :terminus_success,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after]
    end

    # we simply run the {:terminus_success} task to see if it's {#terminus_success} :)
    assert_run my_topology.to_h[:circuit].nodes[:terminus_success].task, seq: [:b], terminus: Trailblazer::Activity::Right
  end

  it "#step raises error with {:id} already used" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step :b,# i am a terminus.
        id: :b, exec_context: new,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :failure,
        adds_insertion_args: [:after]
    end

    assert_raises Trailblazer::Circuit::Adds::IllegalIdError do
      my_topology.step :B, id: :b, exec_context: nil, wirings: {}, adds_insertion_args: [:after]
    end
  end

  it "#step accepts {:magnetic_to}" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

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

    assert_run my_topology.to_h[:circuit], seq: [:a, :c], terminus: Trailblazer::Activity::Right
    assert_run my_topology.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right, target_ctx: {a: Trailblazer::Activity::Left, seq: []}
  end

  it "#step accepts {:adds_for_sequence} which is used in {#compile_wirings} to add rows to the {Sequence}" do
    my_exec_context = T.def_steps(:a)

    new_terminus = Trailblazer::Activity::Terminus.new(semantic: :success)

    my_adds_for_sequence = [
      [
        :my_success,
        row_for_sequence = Trailblazer::Activity::DSL::Sequence::Row.new(
          magnetic_to: :success,
          node: Trailblazer::Circuit::Node[new_terminus, Trailblazer::Circuit::Task::Adapter::LibInterface],
          wirings: {Trailblazer::Activity::Output.new(new_terminus, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
          data: {id: :my_success},
        ),
        :after
      ]
    ]

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step :a, # i am a terminus.
        exec_context: my_exec_context,
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success)},
        adds_insertion_args: [:before],
        adds_for_sequence: my_adds_for_sequence
    end

    assert_outputs my_topology, success: new_terminus
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: new_terminus
  end

  it "TODO: empty Topology has an empty Activity?" do

  end

  it "provides #step" do
    success = nil

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"End.success", magnetic_to: :success,
        adds_insertion_args: [:after],
        wirings: {Trailblazer::Activity::Output.new(success, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}

      step :a, id: :a, exec_context: new, wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a)
    end

    # pp my_topology.config.sequence
    # pp my_topology.to_h[:circuit]

    my_topology_node = Trailblazer::Circuit::Node[my_topology.to_h[:circuit], Trailblazer::Circuit::Processor]

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

  # TODO: these are all kinda normalizer tests.
  it "#step accepts hash as first argument (called macro style)" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step(
        { # explicit hash, not kwargs!
          task: T.def_tasks(:a).method(:a),
          id: :a,
          wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}
        }
      )
    end

    assert_run my_topology, seq: [:a], terminus: Trailblazer::Activity::Right
  end

  it "accepts {:adapter}" do
    my_adapter = ->(task, ctx, flow_options, *) do
      T.def_steps(:a).method(:a).(ctx[:target_ctx], **ctx[:target_ctx]) # mutability sucks.

      return ctx, flow_options, "signal"
    end

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step task: nil,
        adapter: my_adapter,
        id: :a,
        wirings: {Trailblazer::Activity::Output.new("signal", :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new}
    end

    assert_run my_topology, seq: [:a], terminus: "signal"
  end

  it "empty builder is present with {:exec_context} set (because of {#inherited} hook)" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      config.builder = Trailblazer::Activity::DSL::Builder.new(default_options: {step: {}})
    end

    my_topology_subclass = Class.new(my_topology)

    assert_equal my_topology_subclass.config.builder.default_options[:step][:exec_context].class, my_topology_subclass
  end

  it "inheritance doesn't bleed into parents" do
    success = nil
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)

      step task: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), id: :"End.success",
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
    require "trailblazer/activity/finalize"
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      # DISCUSS: is extend the only way? can we use something like another pipe?
      extend Trailblazer::Activity::Finalize # DISCUSS: Feature::Finalize, or where would that go?
      config.builder = Trailblazer::Activity::Finalize::Builder.new(**MyTest.my_options_for_builder)

      config.builder.instance_eval do
        def compile_activity
          @compiled = true
          super
        end
      end

      step :a, id: :a, exec_context: self.new, adds_insertion_args: [:before], wirings: MyTest.wirings_for_terminus
      step :b, id: :b, exec_context: self.new, adds_insertion_args: [:before], wirings: TopologyTest.FIXME___DEFAULT_WIRINGS

      include T.def_steps(:a, :b)
    end

    assert_nil my_topology.config.builder.instance_variable_get(:@compiled)
    assert_equal my_topology.config.activity, nil

    my_topology.finalize

    assert_equal my_topology.config.builder.instance_variable_get(:@compiled), true
    # my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
    #   wiring do
    #     step :a
    #     step :b
    #   end # => this would allow compiling once
    # end

    assert_run my_topology.to_h[:circuit], seq: [:b, :a], terminus: Trailblazer::Activity::Right
  end
end
