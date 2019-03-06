class Trailblazer::Activity
  module DSL
    # Implementing a specific DSL, simplified version of the {Magnetic DSL} from 2017.
    #
    # Produces {Implementation} and {Intermediate}.
    module Linear
      module_function

=begin
      # The following 9 lines are due to the rubbish way Struct works in Ruby.
      def self.Insertion(*args)
        Insertion.new(*args).freeze
      end

      class Insertion < Struct.new(:connections, :outputs, :task, :wrap_task, :sequence_insert, :magnetic_to)
        def initialize(connections:, outputs:, task:, wrap_task:, sequence_insert:, magnetic_to:)
          super(connections, outputs, task, wrap_task, sequence_insert, magnetic_to)
        end
      end
=end

      # {Sequence} consists of rows.
      # {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
      class Sequence < Array
        # Return {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
        def self.create_row(task:, magnetic_to:, wirings:, **options)
          [
            magnetic_to,
            task,
            wirings,
            options # {id: "Start.success"}
          ]
        end

        # @returns Sequence New sequence instance
        # TODO: name it {apply_adds or something}
        def self.insert_row(sequence, new_row, insert_function, *args)
          insert_function.(sequence, [new_row], *args)
        end


        def self.apply_adds(sequence, adds)
          adds.each do |add|
            sequence = insert_row(sequence, *add)
          end

          sequence
        end
      end

      # Sequence
      module Search
        module_function

        # From this task onwards, find the next task that's "magnetic to" {target_color}.
        # Note that we only go forward, no back-references are done here.
        def Forward(output, target_color)
          ->(sequence, me) do
            target_seq_row = sequence[sequence.index(me)+1..-1].find { |seq_row| seq_row[0] == target_color }

            return output, target_seq_row
          end
        end

        def Noop(output)
          ->(sequence, me) do
            return output, [nil,nil,nil,{}] # FIXME
          end
        end

        # Find the seq_row with {id} and connect the current node to it.
        def ById(output, id)
          ->(sequence, me) do
            index          = Insert.find_index(sequence, id) or raise "Couldn't find {#{id}}"
            target_seq_row = sequence[index]

            return output, target_seq_row
          end
        end
      end # Search

      # Sequence
      # Functions to mutate the Sequence by inserting, replacing, or deleting tasks.
      # These functions are called in {insert_task}
      module Insert
        module_function

        # Append {new_row} after {insert_id}.
        def Append(sequence, new_rows, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence.insert(index+1, *new_rows)
        end

        # Insert {new_rows} before {insert_id}.
        def Prepend(sequence, new_rows, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence.insert(index, *new_rows)
        end

        def Replace(sequence, new_rows, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence[index], _ = *new_rows # TODO: replace and insert remaining, if any.
          sequence
        end

        def Delete(sequence, _, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence.delete(sequence[index])
          sequence
        end

        # @private
        def find_index(sequence, insert_id)
          sequence.find_index { |seq_row| seq_row[3][:id] == insert_id } # TODO: optimize id location!
        end

        def find(sequence, insert_id)
          return find_index(sequence, insert_id), sequence.clone # Ruby doesn't have an easy way to avoid mutating arrays :(
        end
      end

      def Merge(old_seq, new_seq, end_id: "End.success") # DISCUSS: also Insert
        new_seq = strip_start_and_ends(new_seq, end_id: end_id)

        seq = Insert.Prepend(old_seq, new_seq, end_id)
      end
      def strip_start_and_ends(seq, end_id:) # TODO: introduce Merge namespace?
        cut_off_index = end_id.nil? ? seq.size : Insert.find_index(seq, end_id) # find the "first" end.

        seq[1..cut_off_index-1]
      end

      module DSL
        module_function

        # Insert the task into the sequence using the {sequence_insert} strategy.
        # @return Sequence sequence after applied insertion
# FIXME: DSL for strategies
        def insert_task(sequence, sequence_insert:, **options)
          new_row = Sequence.create_row(**options)

          # {sequence_insert} is usually a function such as {Linear::Insert::Append} and its arguments.
          seq = Sequence.insert_row(sequence, new_row, *sequence_insert)
        end

        # Add one or several rows to the {sequence}.
        # This is usually called from DSL methods such as {step}.
        def apply_adds_from_dsl(sequence, sequence_insert:, adds:, **options)
          # This is the ADDS for the actual task.
          task_adds = [Sequence.create_row(options), *sequence_insert] # Linear::Insert.method(:Prepend), end_id

          Sequence.apply_adds(sequence, [task_adds] + adds)
        end
      end # DSL

      class State
          # remembers how to call normalizers (e.g. track_color), TaskBuilder
          # remembers sequence
        def initialize(normalizers:, initial_sequence:, **normalizer_options)
          @normalizer         = normalizers # compiled normalizers.
          @sequence           = initial_sequence
          @normalizer_options = normalizer_options
        end

        # Compiles and maintains all final normalizers for a specific DSL.
        class Normalizer
          def compile_normalizer(normalizer_sequence)
            process = Trailblazer::Activity::DSL::Linear::Compiler.(normalizer_sequence)
            process.to_h[:circuit]
          end

          # [gets instantiated at compile time.]
          #
          # We simply compile the activities that represent the normalizers for #step, #pass, etc.
          # This can happen at compile-time, as normalizers are stateless.
          def initialize(normalizer_sequences)
            @normalizers = Hash[
              normalizer_sequences.collect { |name, seq| [name, compile_normalizer(seq)] }
            ]
          end

          # Execute the specific normalizer (step, fail, pass) for a particular option set provided
          # by the DSL user. This is usually when you call Operation::step.
          def call(name, *args)
            normalizer = @normalizers.fetch(name)
            signal, (options, _) = normalizer.(*args)
            options
          end
        end
      end

      # extend Railway( ) # include DSL
      # extend Activity::Intermediate(implementation: , intermediate: ) # NO DSL

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

              # FIXME: ends don't have connections, hence no outputs
              implementations += [[id, Schema::Implementation::Task(task, connections.collect { |output, _| output }) ]]

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
raise "Couldn't find target for #{seq_row}" if target_seq_row.nil?

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

require "trailblazer/activity/dsl/linear/normalizer"
require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"
require "trailblazer/activity/dsl/linear/helper" # FIXME
