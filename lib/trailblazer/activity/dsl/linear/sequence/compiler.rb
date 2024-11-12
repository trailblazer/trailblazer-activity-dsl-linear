module Trailblazer
  class Activity
    module DSL
      module Linear
        class Sequence
          # Compile a {Schema} by computing {implementations} and {intermediate} from a {Sequence}.
          module Compiler
            module_function

            # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
            def find_termini(sequence)
              sequence
                .find_all { |_, _, _, data| data[:stop_event] }
                .collect  { |_, task, _, data| [task, data.fetch(:semantic)] }
                .to_h
            end

            def find_start_task(sequence)
              sequence[0][1]
            end

            def call(sequence, find_stops: Compiler.method(:find_termini), find_start: method(:find_start_task))
              config = Activity::Schema::Intermediate::Compiler::DEFAULT_CONFIG

              nodes_attributes = []

              wiring = sequence.collect do |seq_row|
                _magnetic_to, task, connections, data = seq_row

                id = data[:id]

                # execute all {Search}s for one sequence row.
                connections = find_connections(seq_row, connections, sequence)

                circuit_connections = connections.collect { |output, target_task| [output.signal, target_task] }.to_h

                extensions = (seq_row[3][:extensions] || [])
                # FIXME: move that to {Intermediate::Compiler}?
                config = extensions.inject(config) { |cfg, ext| ext.(config: cfg, id: id, task: task) } # {ext} must return new config hash.

                # nodes_attributes:
                outputs = connections.keys
                nodes_attributes << [
                  id,
                  task,
                  data,
                  outputs
                ]

                [
                  task,
                  circuit_connections
                ]
              end.to_h

              termini = find_stops.(sequence) # {task => semantic}
              start_task = find_start.(sequence)

              circuit = Trailblazer::Activity::Circuit.new(
                wiring,
                termini.keys, # termini
                start_task: start_task
              )

              # activity_outputs = [Activity::Output(steps[last_step_i], :success)]
              activity_outputs = termini.collect { |terminus, semantic| Activity::Output(terminus, semantic) }


              nodes = Schema::Nodes(nodes_attributes)

              Schema.new(circuit, activity_outputs, nodes, config)
            end

            # Execute all search strategies for a row, retrieve outputs and
            # their respective target IDs.
            def find_connections(seq_row, searches, sequence)
              searches.collect do |search|
                output, target_seq_row = search.(sequence, seq_row) # invoke the node's "connection search" strategy.

                target_seq_row = sequence[-1] if target_seq_row.nil? # connect to an End if target unknown. # DISCUSS: make this configurable, maybe?

                [
                  output,
                  target_seq_row[1]
                ]
              end.to_h
            end
          end # Compiler
        end # Sequence
      end
    end
  end
end
