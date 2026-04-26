module Trailblazer
  class Activity
    module DSL
      # A {Sequence} consists of rows, each row represents one step (or task) of an activity
      # and its incoming and outgoing connections.
      # {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
      # A Sequence is compiled into an activity using {Compiler}.
      #

      #
      class Sequence < Circuit::Pipeline # A Sequence inherits from Pipeline so we can use ADDS.
        def initialize(flow_map = {}, start_tuple = nil, nodes = {})
          super(flow_map, start_tuple, nodes)
        end

        def to_a
          flow_map.values
        end

        class Row < Struct.new(:magnetic_to, :node, :wirings, :data)
        end
      end # Sequence
    end
  end
end
