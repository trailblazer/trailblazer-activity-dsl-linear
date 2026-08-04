require "test_helper"

class DslBuilderTest < Minitest::Spec
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
      # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
    }
  end

  it "what" do
    my_block = -> do
      step :a, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]
      step :b, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]

      extend T.def_steps(:a, :b) # FIXME: include is not possible here!
    end

    normalizers = {
      step: Trailblazer::Activity::DSL::Normalizer::Step
    }

    builder = Trailblazer::Activity::DSL::Builder.new(
      normalizers: normalizers,
      # sequence: Trailblazer::Activity::DSL::Sequence.new
    )

    my_activity = builder.(&my_block)

    # builder.finalize! # or do we do this in #call?

    assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right
  end

  it "#new accepts {:sequence}" do

  end

  it "#new accepts {:default_options} that are passed via the ctx but can be overridden by the user" do
    wirings_for_right_to_purple = {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) =>
        Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:purple),
    }

    my_block= -> do
      step :a, wirings: wirings_for_right_to_purple#, adds_insertion_args: [:after, nil]
      step :b, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, #adds_insertion_args: [:after, nil],
        magnetic_to: :failure
      step :c, wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Nil.new()}#, adds_insertion_args: [:after, nil]

      extend T.def_steps(:a, :b, :c) # FIXME: include is not possible here!
    end

    normalizers = {
      step: Trailblazer::Activity::DSL::Normalizer::Step
    }

    builder = Trailblazer::Activity::DSL::Builder.new(
      normalizers: normalizers,

      # the {magnetic_to: :purple} default is picked up by #normalize_magnetic_to and leads to {a}
      # not connecting to {b} but to {c}.
      default_options: {
        magnetic_to: :purple,

        adds_insertion_args: [:after, nil]
      }
    )

    my_activity = builder.(&my_block)

    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: Trailblazer::Activity::Right
  end
end
