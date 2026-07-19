module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      # Class-based DSL to define a circuit (and an activity).
      # NOTE: This is not meant for light-weight library circuits as needed in Reform or Representable,
      #       but for end-user facing business components.
      # NOTE: This used to be named Strategy.
      class Topology
        extend Dry::Configurable
        setting :sequence
        setting :normalizer

        setting :activity

        def self.to_h
          {
            circuit: config.activity.circuit,
          }
        end
      end
    end # DSL
  end
end
