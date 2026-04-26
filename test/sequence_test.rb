require "test_helper"

class SequenceTest < Minitest::Spec
  it "works with empty Sequence" do
    my_seq = Trailblazer::Activity::DSL::Sequence.new

    my_seq = Trailblazer::Circuit::Adds.(
      my_seq,
      [
        :a,
        Object,
        :after
      ]
    )
  end

  it "can be altered using Adds instructions" do
    my_seq = Trailblazer::Activity::DSL::Sequence.new

    my_seq = Trailblazer::Circuit::Adds.(
      my_seq,
      [:a, "a", :after],
      [:b, "b", :after, :a],
    )

    my_seq = Trailblazer::Circuit::Adds.(
      my_seq,
      [
        :c,
        Object,
        :before, :b
      ]
    )

    assert_equal my_seq.flow_map.keys, [:a, :c, :b]
  end

  # DISCUSS: :replace and :delete?
end
