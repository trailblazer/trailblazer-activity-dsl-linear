require "test_helper"

class DslBuilderTest < Minitest::Spec
  def self.FIXME___DEFAULT_WIRINGS
    {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success),
      # Output.new(Left, :failure) => Sequence::Search::Forward.new(:failure)
    }
  end

  def my_options
    normalizers = {
      step: Trailblazer::Activity::DSL::Normalizer::Step
    }

    {
      normalizers: normalizers,
      default_options: {
        step: {
          exec_context: T.def_steps(:a, :b),
        }
      }
    }
  end

  it "{#call} returns {activity, sequence}" do
    my_block = -> do
      step :a, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]
      step :b, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]
    end

    builder = Trailblazer::Activity::DSL::Builder.new(**my_options)

    my_activity, sequence = builder.(&my_block)

    # builder.finalize! # or do we do this in #call?

    assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right
  end

  # Internal unit test to guarantee Finalize compat.
  it "{#update_sequence!} returns {sequence} and doesn't compile anything" do
    my_block = -> do
      step :a, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]
    end

    builder = Trailblazer::Activity::DSL::Builder.new(**my_options)

    sequence = builder.update_sequence!(&my_block)

    assert_equal sequence.to_h[:nodes].keys, [:a]
    # assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right
  end

  it "#new accepts {:sequence}" do

  end


  # it "we can use {#step} directly on the builder instance" do
  #   builder = Trailblazer::Activity::DSL::Builder.new(
  #     **my_options
  #   )

  #   my_activity, sequence = builder.step :a,
  #     wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, adds_insertion_args: [:after, nil]

  #   my_activity, sequence = builder.step :b,
  #     wirings: wirings_for_terminus, adds_insertion_args: [:after, nil]

  #   assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: Trailblazer::Activity::Right
  # end

  it "#new accepts {:default_options} that are passed via the ctx but can be overridden by the user" do
    wirings_for_right_to_purple = {
      Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) =>
        Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:purple),
    }

    my_block= -> do
      step :a, wirings: wirings_for_right_to_purple#, adds_insertion_args: [:after, nil]
      step :b, wirings: DslBuilderTest.FIXME___DEFAULT_WIRINGS, #adds_insertion_args: [:after, nil],
        magnetic_to: :failure
      step :c, wirings: MyTest.wirings_for_terminus#, adds_insertion_args: [:after, nil]
    end

    normalizers = {
      step: Trailblazer::Activity::DSL::Normalizer::Step
    }

    builder = Trailblazer::Activity::DSL::Builder.new(
      normalizers: normalizers,

      # the {magnetic_to: :purple} default is picked up by #normalize_magnetic_to and leads to {a}
      # not connecting to {b} but to {c}.
      default_options: {
        step: {
          magnetic_to: :purple,

          adds_insertion_args: [:after, nil],

          exec_context: T.def_steps(:a, :b, :c)
        }
      }
    )

    my_activity, sequence = builder.(&my_block)

    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: Trailblazer::Activity::Right

    assert_equal sequence.nodes.keys, [:a, :b, :c]
  end

  it "{#clone} accepts {:merge} that merges to all {:default_options} subkeys (:step, etc)" do
    my_builder = Trailblazer::Activity::DSL::Builder.new(
      normalizers: {step: Object},
      default_options: {
        step: {
          magnetic_to: :purple,
        },
        fail: {
          magnetic_to: :failure
        }
      }
    )

    my_builder_clone = my_builder.clone(merge: {exec_context: Module})

    assert_equal my_builder.default_options,
      {
        step: {magnetic_to: :purple},
        fail: {magnetic_to: :failure}
      }

    assert_equal my_builder_clone.default_options,
      {
        step: {magnetic_to: :purple, exec_context: Module},
        fail: {magnetic_to: :failure, exec_context: Module}
      }
  end
end
