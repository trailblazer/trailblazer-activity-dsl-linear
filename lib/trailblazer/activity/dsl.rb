require "trailblazer/activity"
require "dry/configurable"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      module Step
        def step(user_provider = nil, **options) # FIXME: separate module!
          activity, _sequence = config.builder.() { step user_provider, **options }

          self.config.activity = activity
        end
      end # Step

      # DISCUSS: use {config}, make it class method???
      def self.add_to_sequence(sequence, normalizers, user_provider, **options)
        # here, we can inject an :exec_context that keeps configuration.
        adds_for_sequence = DSL::Normalizer.(normalizers, :step, user_provider,
          **options,
          sequence: sequence # TODO: explicitely test that we pass {:sequence}.
        )

        sequence = Circuit::Adds.(
          sequence,
          *adds_for_sequence
        )
      end

      def self.id_for_terminus(semantic:, **)
        "End.#{semantic}" # TODO: use everywhere # FIXME: symbol
      end
    end # DSL
  end
end

require "trailblazer/activity/dsl/sequence"
require "trailblazer/activity/dsl/sequence/search"
require "trailblazer/activity/dsl/sequence/compiler"

require "trailblazer/activity/dsl/builder"

require "trailblazer/activity/dsl/topology"
require "trailblazer/activity/dsl/normalizer"
require "trailblazer/activity/dsl/normalizer/step"
# Trailblazer::Activity::DSL::Topology.config.normalizer = {
#   step: Trailblazer::Activity::DSL::Normalizer::Step
# }

require "trailblazer/activity/dsl/feature/output_tuples"
require "trailblazer/activity/dsl/feature/output_tuples/helper"
require "trailblazer/activity/dsl/feature/output_tuples/normalizer"

require "trailblazer/activity/path"

# TODO: introduce normalizer patching.
# step_normalizer = Trailblazer::Activity::DSL::Topology.config.normalizer.fetch(:step)

# step_normalizer = Trailblazer::Circuit::Adds.(
#   step_normalizer,
#   [
#     :normalize_wirings, Trailblazer::Activity::DSL::Feature::OutputTuples::Normalizer::Node,
#     :before, :build_sequence_row
#   ],
# )

# Trailblazer::Activity::DSL::Topology.config.normalizer = {
#   step: step_normalizer,
# }

# require "trailblazer/activity/dsl/railway"

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
