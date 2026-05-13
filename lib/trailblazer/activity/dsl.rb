require "trailblazer/activity"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    setting :sequence
    setting :normalizer

    def self.step(user_provider = nil, **options) # FIXME: separate module!
      # add to sequence, then recompile the circuit?
      sequence_row_tuple = DSL::Normalizer.(config.normalizer, :step, user_provider, **options)

      config.sequence = Circuit::Adds.(
        config.sequence,
        sequence_row_tuple
      )

      # pp config.sequence

      schema = DSL::Sequence::Compiler.(config.sequence)

      config.circuit = schema[:circuit]
      config.outputs = schema[:outputs]


      # config.node = Circuit::Node

      # TODO: compile_circuit_from_sequence
    end

    module DSL

    end # DSL
  end
end

require "trailblazer/activity/dsl/normalizer"
require "trailblazer/activity/dsl/normalizer/step"
Trailblazer::Activity.config.normalizer = {
  step: Trailblazer::Activity::DSL::Normalizer::Step
}

require "trailblazer/activity/dsl/sequence"
require "trailblazer/activity/dsl/sequence/search"
require "trailblazer/activity/dsl/sequence/compiler"

# DISCUSS: where to move this?
module Trailblazer
  class Activity
    config.sequence = DSL::Sequence.new

    # add the default "terminus", a concept from Activity.
    # id_for_success_terminus = :"End.success"

    # config.sequence = Circuit::Adds.(
    #   config.sequence,
    #   [
    #     id_for_success_terminus,
    #     DSL::Sequence::Row.new(
    #       magnetic_to: :success,
    #       node: Circuit::Node[id_for_success_terminus, Terminus::Success.new(semantic: :success), Circuit::Task::Adapter::LibInterface],
    #       wirings: {},
    #       data: {id: id_for_success_terminus, terminus: true, semantic: :success},
    #     ),
    #     :before
    #   ]
    # )
  end
end
