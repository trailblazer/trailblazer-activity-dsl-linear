require "test_helper"

class AddsForTaskWrapExtensionTest < Minitest::Spec
  # TaskWrap extension = runtime extension
  class AddToSeq < Struct.new(:ary)
    def call(ctx, flow_options, signal, target_ctx:, **)
      target_ctx = target_ctx.merge(seq: target_ctx[:seq] + ary)

      return ctx.merge(target_ctx: target_ctx), flow_options, signal
    end
  end

  it "low-level {:adds_for_task_wrap}" do
    my_normalizer = Trailblazer::Circuit::Adds.(
      Trailblazer::Activity::DSL::Normalizer::Step,
      [:bla, Trailblazer::Activity::DSL::Feature::Extension::TaskWrap::Normalizer::Node, :after, :build_task_wrap_pipeline]
    )

    my_tw_extension_adds_1 = [
      :"add_1",
      Trailblazer::Circuit::Node[AddToSeq.new([1]), Trailblazer::Circuit::Task::Adapter::LibInterface],
      :after,
      :"task_wrap.call_task"
    ]

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder(step_normalizer: my_normalizer))

      step :b,# i am a terminus.
        exec_context: T.def_steps(:b),
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after],
        adds_for_task_wrap: [
          my_tw_extension_adds_1
        ]
    end

    assert_run my_topology, terminus: Trailblazer::Activity::Right, seq: [:b, 1]
  end
end

class OptionsExtensionsTest < Minitest::Spec
  # Add {:my_id} to Sequence/row/data
  def my_id_options_extension(ctx, flow_options, _, id:, **)
    ctx = ctx.merge(my_id: id.to_s.upcase, Trailblazer::Activity::DSL::Feature::Data::Variable.new => [:my_id])

    return ctx, flow_options
  end

  # TODO: add extension that adds {:adds_for_task_wrap}

  it "we can pass {:options_extensions} and alter the step's normalizer ctx" do
    my_normalizer = Trailblazer::Circuit::Adds.(
      Trailblazer::Activity::DSL::Normalizer::Step,
      [:bla, Trailblazer::Activity::DSL::Feature::Extension::TaskWrap::Normalizer::Node, :after, :build_task_wrap_pipeline],
      [:yo,  Trailblazer::Activity::DSL::Feature::Extension::Options::Normalizer::Node, :after, :build_task_wrap_pipeline],

      [
        :compile_data, Trailblazer::Activity::DSL::Feature::Data::Normalizer::Node,
        :before, :build_sequence_row
      ],
    )

    my_id_extension = method(:my_id_options_extension)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**MyTest.my_options_for_builder(step_normalizer: my_normalizer))

      step :b,# i am a terminus.
        exec_context: T.def_steps(:b),
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new},
        magnetic_to: :successs,
        adds_insertion_args: [:after],
        adds_for_task_wrap: [
          # my_tw_extension_adds_1
        ],
        options_extensions: [
          my_id_extension
        ]
    end

    assert_run my_topology, terminus: Trailblazer::Activity::Right, seq: [:b]
    assert_equal my_topology.config.builder.sequence.to_a.to_h[:b].data, {id: :b, my_id: "B"}
  end
end



# two different extensions
  # normalizer extensions are run and can add options to ctx (e.g. also modify :adds_for_task_wrap)
  # :adds_for_task_wrap are then applied in a separate normalizer step (feature)
