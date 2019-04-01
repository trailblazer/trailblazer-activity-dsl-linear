module Trailblazer
  class Activity
    module DSL
      module Linear
        # Compile a {Schema} by computing {implementations} and {intermediate} from a {Sequence}.
        module Compiler
          module_function

          # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
          def find_stop_task_ids(intermediate_wiring)
            intermediate_wiring.collect { |task_ref, outs| task_ref.data[:stop_event] ? task_ref.id : nil }.compact
          end

          # The first task in the wiring is the default start task.
          def find_start_task_ids(intermediate_wiring)
            [intermediate_wiring.first.first.id]
          end

          def call(sequence, find_stops: method(:find_stop_task_ids), find_start: method(:find_start_task_ids))
            _implementations, intermediate_wiring =
              sequence.inject([[], []]) do |(implementations, intermediates), seq_row|
                magnetic_to, task, connections, data = seq_row
                id = data[:id]

                # execute all {Search}s for one sequence row.
                connections = find_connections(seq_row, connections, sequence)

                # FIXME: {:extensions} should be initialized
                implementations += [[id, Schema::Implementation::Task(task, connections.collect { |output, _| output }, data[:extensions] || []) ]]

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

            intermediate   = Schema::Intermediate.new(Hash[intermediate_wiring], stop_task_refs, start_task_ids)
            implementation = Hash[_implementations]

            Schema::Intermediate.(intermediate, implementation) # implemented in the generic {trailblazer-activity} gem.
          end

          # private

          def find_connections(seq_row, strategies, sequence)
            strategies.collect do |search|
              output, target_seq_row = search.(sequence, seq_row) # invoke the node's "connection search" strategy.

              target_seq_row = sequence[-1] if target_seq_row.nil? # connect to an End if target unknown. # DISCUSS: make this configurable, maybe?

              [
                output,                                     # implementation
                target_seq_row[3][:id],  # intermediate   # FIXME. this sucks.
                target_seq_row # DISCUSS: needed?
              ]
            end.compact
          end
        end # Compiler
      end
    end
  end
end
