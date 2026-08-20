require "test_helper"

class SubprocessTest < Minitest::Spec
  def self.my_options_for_builder(exec_context:)
    {
      normalizers: {
        step: Trailblazer::Activity::DSL::Normalizer::Step,
      },
      default_options: {
        step: {
          exec_context: exec_context,
          wirings: {
            Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
          },
          adds_insertion_args: [:after]
        }
      }
    }
  end

  it "#Subprocess()" do
    my_nested_activity = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**SubprocessTest.my_options_for_builder(exec_context: new))

      step :b,
        wirings: {
          Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new,
        }

      include T.def_steps(:b)
    end

    my_activity = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**SubprocessTest.my_options_for_builder(exec_context: new))

      step :a, exec_context: new
      step Subprocess(my_nested_activity), id: "FIXME"
      step :c,
        wirings: {
          Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new,
        }

      include T.def_steps(:a, :c)
    end

    assert_run my_activity, terminus: Trailblazer::Activity::Right, seq: [:a, :b, :c]
  end
end
