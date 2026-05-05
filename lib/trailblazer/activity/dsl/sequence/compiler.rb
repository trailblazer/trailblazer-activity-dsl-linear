module Trailblazer
  class Activity
    module DSL
      class Sequence
        # Compile a {Schema} from a {Sequence} into a {Circuit}.
        # This is the heart of the `dsl` gem where the user's DSL instructions
        # finally get transformed into a runnable Activity.
        module Compiler
          module_function

          # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
          def find_termini_rows(sequence_ary) # FIXME: actually, we only need to check if the terminus task has any outgoing connections?
            sequence_ary
              .find_all { |id, row| row.data[:terminus] }
              .to_h
          end

          def find_start_tuple(sequence_ary)
            id, row = sequence_ary[0]

            [id, row.node]
          end

          # The Compiler retrieves an array of rows composed by the DSL (normalizer).
          # Per design, it doesn't know about {Sequence < Pipeline}.
          def call(sequence, find_start: method(:find_start_tuple))
            sequence_ary = sequence.to_a # DISCUSS: since we expect a Sequence instance, we have to convert it (instead of #collect).

            termini_rows = find_termini_rows(sequence_ary) # {task => semantic}

            nodes_attributes = []

            flow_map = sequence_ary.collect do |id, seq_row|
              # raise seq_row.inspect unless seq_row.is_a?(Sequence::Row)
              _magnetic_to, node, connections, data = seq_row.to_a

              is_terminus = termini_rows[id]

              # execute all {Search}s for one sequence row.
              if is_terminus
                connections = {}
              else
                connections = find_connections(seq_row, connections, sequence_ary.to_h.values)
              end

              connections_for_flow_map = connections.collect { |output, node| [output.signal, node.id] }.to_h # DISCUSS: should a Node really have a


              # nodes_attributes:
              # outputs = connections.keys

              # nodes_attributes << [
              #   id,
              #   task,
              #   data,
              #   outputs
              # ]

              [
                id,
                connections_for_flow_map
              ]
            end.to_h

            start_tuple = find_start.(sequence_ary)
            nodes       = sequence_ary.collect { |id, row| [id, row.node] }.to_h

            outputs = termini_rows.collect do |id, seq_row|
              semantic = seq_row.data.fetch(:semantic)
              [
                semantic,
                Activity::Output.new(seq_row.node.task, semantic)
              ]
            end.to_h

            circuit = Circuit.new(
              flow_map,
              start_tuple,
              nodes
              # termini.keys, # termini
            )

            # return Activity.new(circuit: circuit, outputs: outputs)
            # return Class.new(Activity)
            return {circuit: circuit, outputs: outputs} # DISCUSS: introduce Schema?

            # Schema.new(circuit, activity_outputs, nodes, config)
          end

          # Execute all search strategies for a row, retrieve outputs and
          # their respective target IDs.
          def find_connections(seq_row, searches, sequence_ary)
            searches.collect do |output, search|
              target_seq_row = search.(sequence_ary, seq_row) # invoke the node's "connection search" strategy.

              target_seq_row = sequence_ary[-1] if target_seq_row.nil? # connect to an End if target unknown. # DISCUSS: make this configurable, maybe?

              [
                output,
                target_seq_row.node
              ]
            end.to_h
          end
        end # Compiler
      end # Sequence
    end
  end
end
