require "trailblazer/activity"

module Trailblazer
  class Activity
    setting :sequence
    config.sequence = []

    setting :normalizer


    def self.step(method_name, **options) # FIXME: separate module!
      # add to sequence, then recompile the circuit?
      sequence_row = DSL::Normalizer.(config.normalizer, :step, method_name, **options)

      config.sequence += [sequence_row]

      schema = DSL::Sequence::Compiler.(config.sequence)

      pp schema

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
