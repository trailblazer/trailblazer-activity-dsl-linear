require "trailblazer/activity"

module Trailblazer
  class Activity
    setting :sequence
    config.sequence = []

    def self.step(method_name) # FIXME: separate module!
      # add to sequence, then recompile the circuit?
      sequence_row = [method_name] # TODO: run normalizer here!

      config.sequence += [sequence_row]

      # TODO: compile_circuit_from_sequence
    end
  end
end
