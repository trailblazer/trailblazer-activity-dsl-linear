require "test_helper"

class DataTest < Minitest::Spec
  def self.my_options_for_builder
    {
      normalizers: {
        step: MyNormalizer,
      },
      default_options: {
        step: {
          exec_context: "new",
          wirings: FIXME___DEFAULT_WIRINGS(),
          adds_insertion_args: [:after],
        }
      }
    }
  end
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
    }
  end
  # FIXME: move those two guys to test_helper.

  MyNormalizer = Trailblazer::Circuit::Adds.(
    Trailblazer::Activity::DSL::Normalizer::Step,
    [
      :compile_data, Trailblazer::Activity::DSL::Feature::Data::Normalizer::Node,
      :before, :build_sequence_row
    ],
  )

  it "allows storing variables in Sequence's {data} field" do
    my_activity = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**DataTest.my_options_for_builder)

      step :a
      step :b,
        Trailblazer::Activity::DSL::Feature::Data.Variable => [:status, :mode],
        status: "awake",
        bogus: true,
        mode: Object
    end

    assert_equal my_activity.config.builder.sequence.nodes[:b].data, {id: :b, status: "awake", mode: Object}
  end
end
