require "test_helper"

class NormalizerTest < Minitest::Spec
  it "Normalizer API" do
    # Your code to customize the DSL normalizer.
    module NormalizerExtensions
      def self.upcase_id(ctx, id:, **)
        ctx[:id] = id.to_s.upcase
      end
    end

    application_operation = Class.new(Trailblazer::Activity::Railway) do
      Trailblazer::Activity::DSL::Linear::Normalizer.extend!(self, :step) do |normalizer|
        # this is where your extending code enters the stage:
        Trailblazer::Activity::DSL::Linear::Normalizer.prepend_to(
          normalizer,
          "activity.normalize_override", # step after "activity.normalize_id"
          {
            "my.upcase_id" => Trailblazer::Activity::DSL::Linear::Normalizer.Task(NormalizerExtensions.method(:upcase_id)),
          }
        )
      end

      step :model
      pass :find_id
    end

    graph = Trailblazer::Activity::Introspect.Graph(application_operation)

    #@ we don't find a row named {:model}
    assert_equal graph.find(:model), nil
    #@ we find a {"MODEL"} row
    assert_equal graph.find("MODEL").id, "MODEL"
    #@ {#pass} still has lowercase ID.
    assert_equal graph.find(:find_id).id, :find_id
  end

  it "#prepend_to  and #replace" do
    pipe = Trailblazer::Activity::TaskWrap::Pipeline.new([])

  #@ prepend_to empty pipe.
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

  #@ replace existing element
    pipe3 = Trailblazer::Activity::DSL::Linear::Normalizer.replace(
      pipe2,
      "railway.outputs",
      ["Id: 5", "task 5"]
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

    assert_equal inspect(pipe3), %{#<Trailblazer::Activity::TaskWrap::Pipeline:
 @sequence=
  [["Id: 5", "task 5"],
   ["Id: 3", "task 3"],
   ["Id: 4", "task 4"],
   ["railway.connections", "task 2"]]>
}
  end

  # FIXME: from activity/adds_test.rb
  def inspect(pipe)
    pipe.pretty_inspect.sub(/0x\w+/, "")
  end
end
