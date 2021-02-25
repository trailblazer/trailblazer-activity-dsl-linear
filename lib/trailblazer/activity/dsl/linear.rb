require "trailblazer-activity"

class Trailblazer::Activity
  module DSL
    # Implementing a specific DSL, simplified version of the {Magnetic DSL} from 2017.
    #
    # Produces {Implementation} and {Intermediate}.
    module Linear
      module_function

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
        def self.insert_row(sequence, row:, insert:)
          insert_function, *args = insert

          insert_function.(sequence, [row], *args)
        end

        def self.apply_adds(sequence, adds)
          adds.each do |add|
            sequence = insert_row(sequence, **add)
          end

          sequence
        end

        class IndexError < IndexError
          attr_reader :step_id

          def initialize(sequence, step_id)
            @step_id  = step_id
            valid_ids = sequence.collect{ |row| row[3][:id].inspect }

            message = "\n" \
              "\e[31m#{@step_id.inspect} is not a valid step ID. Did you mean any of these ?\e[0m\n" \
              "\e[32m#{valid_ids.join("\n")}\e[0m"

            super(message)
          end
        end
      end

      # Sequence
      module Search
        module_function

        # From this task onwards, find the next task that's "magnetic to" {target_color}.
        # Note that we only go forward, no back-references are done here.
        def Forward(output, target_color)
          ->(sequence, me) do
            target_seq_row = find_in_range(sequence[sequence.index(me)+1..-1], target_color)

            return output, target_seq_row
          end
        end

        # Tries to find a track colored step by doing a Forward-search, first, then wraps around going
        # through all steps from sequence start to self.
        def WrapAround(output, target_color)
          ->(sequence, me) do
            my_index      = sequence.index(me)
            # First, try all elements after me, then go through the elements preceding myself.
            wrapped_range = sequence[my_index+1..-1] + sequence[0..my_index-1]

            target_seq_row = find_in_range(wrapped_range, target_color)

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
            index          = Insert.find_index(sequence, id) or return output, sequence[0] # FIXME # or raise "Couldn't find {#{id}}"
            target_seq_row = sequence[index]

            return output, target_seq_row
          end
        end

        # @private
        def find_in_range(range, target_color)
          target_seq_row = range.find { |seq_row| seq_row[0] == target_color }
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
          index = find_index(sequence, insert_id) or raise Sequence::IndexError.new(sequence, insert_id)

          return index, sequence.clone # Ruby doesn't have an easy way to avoid mutating arrays :(
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
          seq = Sequence.insert_row(sequence, row: new_row, insert: sequence_insert)
        end

        # Add one or several rows to the {sequence}.
        # This is usually called from DSL methods such as {step}.
        def apply_adds_from_dsl(sequence, sequence_insert:, adds:, **options)
          # This is the ADDS for the actual task.
          task_add = {row: Sequence.create_row(**options), insert: sequence_insert} # Linear::Insert.method(:Prepend), end_id

          Sequence.apply_adds(sequence, [task_add] + adds)
        end
      end # DSL

    end
  end
end

require "trailblazer/activity/dsl/linear/normalizer"
require "trailblazer/activity/dsl/linear/state"
require "trailblazer/activity/dsl/linear/helper"
require "trailblazer/activity/dsl/linear/strategy"
require "trailblazer/activity/dsl/linear/compiler"
require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"
require "trailblazer/activity/dsl/linear/variable_mapping"
