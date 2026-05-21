module Trailblazer
  class Activity
    module DSL
      class Sequence
        # Compile a {Schema} from a {Sequence} into a {Circuit}.
        # This is the heart of the `dsl` gem where the user's DSL instructions
        # finally get transformed into a runnable Activity.
        module Compiler
          module_function

          def find_start_tuple(sequence_ary)
            id, row = sequence_ary[0]

            [id, row.node]
          end

          # The Compiler retrieves an array of rows composed by the DSL (normalizer).
          # Per design, it doesn't know about {Sequence < Pipeline}.
          def call(sequence, find_start: method(:find_start_tuple))
            sequence_ary = sequence.to_a # DISCUSS: since we expect a Sequence instance, we have to convert it (instead of #collect).

            nodes_attributes = []

            id_to_connections = compile_connections(sequence_ary)
            flow_map          = compile_flow_map(id_to_connections)
            outputs           = compile_outputs(id_to_connections)

            start_tuple = find_start.(sequence_ary)
            nodes       = sequence_ary.collect { |id, row| [id, row.node] }.to_h

            circuit = Circuit.new(
              flow_map,
              start_tuple,
              nodes
            )

            # return Activity.new(circuit: circuit, outputs: outputs)
            # return Class.new(Activity)
            return {circuit: circuit, outputs: outputs} # DISCUSS: introduce Schema?

            # Schema.new(circuit, activity_outputs, nodes, config)
          end

          # Returns {id => {<signal> => target_id}, ...}
          def compile_connections(sequence_ary)
            sequence_ary.collect do |id, seq_row|
              _magnetic_to, node, connections, data = seq_row.to_a

              # execute all {Search}s for one sequence row.
              # puts "finding connections for #{id}"
              connections = find_connections(seq_row, connections, sequence_ary.to_h.values)

              [
                id,
                connections
              ]
            end
          end

          def compile_flow_map(id_to_connections)
            id_to_connections.collect do |id, connections|
              connections_for_flow_map = connections.collect { |output, target_id| [output.signal, target_id] }.to_h

              [
                id,
                connections_for_flow_map
              ]
            end.to_h
          end

          # DISCUSS: currently, we "detect" this activity's outputs by finding all signals that lead to {nil}.
          def compile_outputs(id_to_connections)
            id_to_connections.flat_map do |id, connections|
              connections
                .find_all { |output, target_id| target_id.nil? }
                .collect { |output, target_id| [output.semantic, output] }
            end.to_h
          end

          # Execute all search strategies for a row, retrieve outputs and
          # their respective target IDs.
          def find_connections(seq_row, searches, sequence_ary)
            searches.collect do |output, search|
              target_node_id = search.(sequence_ary, seq_row) # invoke the node's "connection search" strategy.

              [
                output,
                target_node_id
              ]
            end.to_h
          end
        end # Compiler
      end # Sequence
    end
  end
end
