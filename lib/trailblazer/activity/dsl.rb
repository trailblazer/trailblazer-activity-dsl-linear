require "trailblazer/activity"
require "dry/configurable"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.

    module Compile # NOTE: this code is unrelated to DSL and *how* the sequence was built.
      def self.compile_activity!(config)
        activity = DSL::Sequence::Compiler.(config.sequence)

        config.activity = activity
      end
    end

    module DSL
      module Step
        def step(user_provider = nil, **options) # FIXME: separate module!
          # add to sequence, then recompile the circuit?
          config.sequence = DSL.add_to_sequence(config.sequence, config.normalizer, user_provider, **options)

          Compile.compile_activity!(config) # DISCUSS: omit this when we're in zeitwerk env.

          # config.node = Circuit::Node

          # TODO: compile_circuit_from_sequence
        end
      end # Step

      # DISCUSS: use {config}, make it class method???
      def self.add_to_sequence(sequence, normalizer, user_provider, **options)
        sequence_row_tuple = DSL::Normalizer.(normalizer, :step, user_provider, **options)

        sequence = Circuit::Adds.(
          sequence,
          sequence_row_tuple
        )

        # pp sequence.flow_map; return sequence
      end
    end # DSL
  end
end

require "trailblazer/activity/dsl/sequence"
require "trailblazer/activity/dsl/sequence/search"
require "trailblazer/activity/dsl/sequence/compiler"

require "trailblazer/activity/dsl/topology"
require "trailblazer/activity/dsl/normalizer"
require "trailblazer/activity/dsl/normalizer/step"
Trailblazer::Activity::DSL::Topology.config.normalizer = {
  step: Trailblazer::Activity::DSL::Normalizer::Step
}


# DISCUSS: where to move this?

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
