module Trailblazer
  class Activity
    module DSL
      class Topology
        # Shortcuts for the DSL, included in {Topology} so they're available to all
        # Topology users such as {Railway} or {Operation}.
        module Helper
          # This is the namespace container for {Contract::}, {Policy::} and friends.
          module Constants
          end
        end
      end
    end
  end
end
