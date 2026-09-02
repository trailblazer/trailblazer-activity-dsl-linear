require "test_helper"

class AddsForTaskWrapExtensionTest < Minitest::Spec
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
    }
  end


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
      [:bla, Trailblazer::Activity::DSL::Feature::TaskWrap::Normalizer::Node, :after, :build_task_wrap_pipeline]
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



# two different extensions
  # normalizer extensions are run and can add options to ctx (e.g. also modify :adds_for_task_wrap)
  # :adds_for_task_wrap are then applied in a separate normalizer step (feature)
