module Trailblazer
  class Activity
    module DSL
      module Linear
        class Sequence
          # Compile a {Schema} by computing {implementations} and {intermediate} from a {Sequence}.
          module Compiler
            module_function

            # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
            def find_termini(intermediate_wiring)
              intermediate_wiring
                .find_all { |task_ref, _| task_ref.data[:stop_event] }
                .collect  { |task_ref, _| [task_ref.id, task_ref.data.fetch(:semantic)] }
                .to_h
            end

            # The first task in the wiring is the default start task.
            def find_start_task_id(intermediate_wiring) # FIXME: shouldn't we use sequence here? and Row#id?
              intermediate_wiring.first.first.id
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

              start_task_ids = find_start.(intermediate_wiring)
              stop_task_refs = find_stops.(intermediate_wiring)

              intermediate   = Schema::Intermediate.new(intermediate_wiring.to_h, stop_task_refs, start_task_ids)
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
          end # Compiler
        end # Sequence
      end
    end
  end
end
