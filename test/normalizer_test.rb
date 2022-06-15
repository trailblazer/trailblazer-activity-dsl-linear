require "test_helper"

class NormalizerTest < Minitest::Spec
  it "#prepend_to" do
    pipe = Trailblazer::Activity::TaskWrap::Pipeline.new([])

    pipe1 = Trailblazer::Activity::DSL::Linear::Normalizer.prepend_to(
      pipe,
      # "activity.wirings",
      nil,
      {
        "railway.outputs"     => "task 1",
        "railway.connections" => "task 2",
      }
    )

  #@ prepend_to existing row
    pipe2 = Trailblazer::Activity::DSL::Linear::Normalizer.prepend_to(
      pipe1,
      "railway.connections",
      {
        "Id: 3" => "task 3",
        "Id: 4" => "task 4",
      }
    )

    assert_equal inspect(pipe1), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=[[\"railway.outputs\", \"task 1\"], [\"railway.connections\", \"task 2\"]]>
}

    assert_equal inspect(pipe2), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [[\"railway.outputs\", \"task 1\"],
   [\"Id: 3\", \"task 3\"],
   [\"Id: 4\", \"task 4\"],
   [\"railway.connections\", \"task 2\"]]>
}
  end

  # FIXME: from activity/adds_test.rb
  def inspect(pipe)
    pipe.pretty_inspect.sub(/0x\w+/, "")
  end
end
