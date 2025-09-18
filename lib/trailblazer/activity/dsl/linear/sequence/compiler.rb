module Trailblazer
  class Activity
    module DSL
      module Linear
        class Sequence
          # Compile a {Schema} from a {Sequence} into a {Circuit}.
          # This is the heart of the `dsl` gem where the user's DSL instructions
          # finally get transformed into a runnable Activity.
          module Compiler
            module_function

            # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
            def find_termini(sequence_ary)
              sequence_ary
                .find_all { |row| row.data[:stop_event] }
                .collect  { |row| [row.task, row.data.fetch(:semantic)] }
                .to_h
            end

            def find_start_task(sequence_ary)
              sequence_ary[0].task
            end

            # The Compiler retrieves an array of rows composed by the DSL (normalizer).
            # Per design, it doesn't know about {Sequence < Pipeline}.
            def call(sequence_ary, find_stops: Compiler.method(:find_termini), find_start: method(:find_start_task))
              config = {wrap_static: {}} # TODO: where does this come from?

              nodes_attributes = []

              wiring = sequence_ary.collect do |seq_row|
                # raise seq_row.inspect unless seq_row.is_a?(Sequence::Row)
                _magnetic_to, task, connections, data, task_wrap = seq_row.to_a
                id = seq_row.data.fetch(:id)

                # execute all {Search}s for one sequence row.
                connections = find_connections(seq_row, connections, sequence_ary)

                circuit_connections = connections.collect { |output, target_task| [output.signal, target_task] }.to_h

                config[:wrap_static][task] = task_wrap

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

              termini = find_stops.(sequence_ary) # {task => semantic}
              start_task = find_start.(sequence_ary)

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
            def find_connections(seq_row, searches, sequence_ary)
              searches.collect do |search|
                output, target_seq_row = search.(sequence_ary, seq_row) # invoke the node's "connection search" strategy.

                target_seq_row = sequence_ary[-1] if target_seq_row.nil? # connect to an End if target unknown. # DISCUSS: make this configurable, maybe?

                [
                  output,
                  target_seq_row.task
                ]
              end.to_h
            end
          end # Compiler
        end # Sequence
      end
    end
  end
end
