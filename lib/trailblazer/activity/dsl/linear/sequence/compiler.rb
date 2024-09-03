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
              nodes_attributes = []

              wiring = sequence.collect do |seq_row|
                _magnetic_to, task, connections, data = seq_row

                id = data[:id]

                # execute all {Search}s for one sequence row.
                connections = find_connections(seq_row, connections, sequence)

                circuit_connections = connections.collect { |output, target_task| [output.signal, target_task] }.to_h

                # nodes_attributes:
                outputs = connections.keys
                nodes_attributes << [
                  id,
                  task,
                  {},  # TODO: allow adding data from implementation.
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

              config = Activity::Schema::Intermediate::Compiler::DEFAULT_CONFIG

              return circuit,
                activity_outputs,
                Schema::Nodes(nodes_attributes),
                config

              Schema.new(circuit, outputs, nodes, config)
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

            # FIXME: remove me once the direct Schema compilation is running and benchmarked.
            module WithIntermediate
              module_function


              # The first task in the wiring is the default start task.
              def find_start_task_id(intermediate_wiring) # FIXME: shouldn't we use sequence here? and Row#id?
                intermediate_wiring.first.first.id
              end

              def find_termini(intermediate_wiring)
                intermediate_wiring
                  .find_all { |task_ref, _| task_ref.data[:stop_event] }
                  .collect  { |task_ref, _| [task_ref.id, task_ref.data.fetch(:semantic)] }
                  .to_h
              end

              def call(sequence, find_stops: method(:find_termini), find_start: method(:find_start_task_id))
                _implementations, intermediate_wiring =
                  sequence.inject([[], []]) do |(implementations, intermediates), seq_row|
                    _magnetic_to, task, connections, data = seq_row
                    id = data[:id]

                    # execute all {Search}s for one sequence row.
                    connections = find_connections(seq_row, connections, sequence)

                    # FIXME: {:extensions} should be initialized
                    implementations += [[id, Schema::Implementation::Task(task, connections.collect { |output, _| output }, data[:extensions] || [])]]

                    intermediates += [
                      [
                        Schema::Intermediate::TaskRef(id, data),
                        # Compute outputs.
                        connections.collect { |output, target_id| Schema::Intermediate::Out(output.semantic, target_id) }
                      ]
                    ]

                    [implementations, intermediates]
                  end

                start_task_id         = find_start.(intermediate_wiring)
                terminus_to_semantic  = find_stops.(intermediate_wiring)

                intermediate   = Schema::Intermediate.new(intermediate_wiring.to_h, terminus_to_semantic, start_task_id)
                implementation = _implementations.to_h

                Schema::Intermediate::Compiler.(intermediate, implementation) # implemented in the generic {trailblazer-activity} gem.
              end

              # private

              # Execute all search strategies for a row, retrieve outputs and
              # their respective target IDs.
              def find_connections(seq_row, searches, sequence)
                searches.collect do |search|
                  output, target_seq_row = search.(sequence, seq_row) # invoke the node's "connection search" strategy.

                  target_seq_row = sequence[-1] if target_seq_row.nil? # connect to an End if target unknown. # DISCUSS: make this configurable, maybe?

                  [
                    output,
                    target_seq_row.id
                  ]
                end
              end
            end # WithIntermediate
          end # Compiler
        end # Sequence
      end
    end
  end
end
