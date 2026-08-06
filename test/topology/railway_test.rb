class TopologyRailwayTest < Minitest::Spec
  it "what" do
    my_railway_builder = Trailblazer::Activity::DSL::Builder.new(
      normalizers: {
        step: Trailblazer::Activity::DSL::Normalizer::Step,
        fail: Trailblazer::Activity::DSL::Normalizer::Step, # FIXME.
      },
        # sequence: Trailblazer::Activity::DSL::Sequence.new
      default_options: {
        step: {},
        fail: {},
      }
    )

    success_terminus = Trailblazer::Activity::Terminus::Success.new(semantic: :success)

    activity, _ = my_railway_builder.() do
      step task: success_terminus,
        wirings: MyTest.wirings_for_terminus(signal: success_terminus),
        id: Trailblazer::Activity::DSL.id_for_terminus(semantic: :success),
        magnetic_to: :success
    end


    # my_activity = Class.new(Trailblazer::Activity::Railway) do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      config.builder = my_railway_builder
      config.activity = activity # FIXME: it's only one line, but it's redundant to DSL#step.
      # TODO: compile here, so we can run "empty" topologies.

      step T.def_steps(:a).method(:a), wirings: {
        Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
          # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
        },
        adds_insertion_args: [:before, Trailblazer::Activity::DSL.id_for_terminus(semantic: :success)]

      # include T.def_steps(:a) # FIXME: test :instance_method with exec_context set by normalizer.
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: success_terminus
  end
end
