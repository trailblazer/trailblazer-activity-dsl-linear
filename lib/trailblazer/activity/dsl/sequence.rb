module Trailblazer
  class Activity
    module DSL
      # A {Sequence} consists of rows, each row represents one step (or task) of an activity
      # and its incoming and outgoing connections.
      # {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
      # A Sequence is compiled into an activity using {Compiler}.
      #

      #
      class Sequence < Circuit # A Sequence inherits from Circuit so we can use ADDS.
        def initialize(flow_map = {}, start_tuple = nil, nodes = {})
          super(flow_map, start_tuple, nodes)
        end

        # This is for the Compiler.
        def to_a
          flow_map.collect { |id,| [id, nodes[id]] }.to_a
        end

        # DISCUSS: {wirings} could be named "outputs to searches" or "output mappings".
        class Row < Struct.new(:magnetic_to, :node, :wirings, :data, keyword_init: true)
        end
      end # Sequence
    end
  end
end
