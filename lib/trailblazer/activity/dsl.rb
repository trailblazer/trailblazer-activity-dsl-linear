require "trailblazer/activity"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    setting :sequence
    setting :normalizer

    def self.step(user_provider = nil, **options) # FIXME: separate module!
      # add to sequence, then recompile the circuit?
      config.sequence = DSL::Step.add_to_sequence(config.sequence, config.normalizer, user_provider, **options)

      Compile.compile_schema!(config) # DISCUSS: omit this when we're in zeitwerk env.

      # config.node = Circuit::Node

      # TODO: compile_circuit_from_sequence
    end

    module Compile # NOTE: this code is unrelated to DSL and *how* the sequence was built.
      def self.compile_schema!(config)
        schema = DSL::Sequence::Compiler.(config.sequence)

        config.circuit = schema[:circuit]
        config.outputs = schema[:outputs]
      end
    end

    module DSL
      module Step
        module_function

        # DISCUSS: use {config}, make it class method???
        def add_to_sequence(sequence, normalizer, user_provider, **options)
          sequence_row_tuple = DSL::Normalizer.(normalizer, :step, user_provider, **options)

          sequence = Circuit::Adds.(
            sequence,
            sequence_row_tuple
          )

          # pp sequence.flow_map; return sequence
        end
      end # Step
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
