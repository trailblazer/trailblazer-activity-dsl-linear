require "test_helper"

class TopologyConfigureTest < Minitest::Spec
  it "we can add {default_options}, add steps to all normalizers and include helpers" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder)
    end

    # require "trailblazer/developer"
    # Trailblazer::Developer.puts(my_topology.to_h[:circuit])

    my_helper = Module.new do
      def MyHelper
        {my_helper_variable: true}
      end
    end

    def my_normalizer_step(ctx, flow_options, _, my_helper_variable:, my_default:, **)
      ctx = ctx.merge(data: {my_helper_variable: my_helper_variable, my_default: my_default})

      return ctx, flow_options
    end

    Trailblazer::Activity::DSL::Topology::Configure.call!(
      my_topology,
      defaults: {my_default: []}, # merge to all {default_options} for normalizer.
      helpers: [my_helper],
      adds: [
        [
          :my_normalizer_step,
          Trailblazer::Circuit::Node[method(:my_normalizer_step), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :before, :build_task_wrap_node
        ],
      ]
    )

    my_topology.class_eval do
      step :b,# i am a terminus.
        exec_context: T.def_steps(:b),
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        **MyHelper() # we can call MyHelper now.
      end

    assert_equal my_topology.config.builder.sequence.to_a.to_h[:b].data, {id: :b, my_helper_variable: true, my_default: []}
  end
end
