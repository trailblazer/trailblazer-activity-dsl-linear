class Trailblazer::Activity
  module DSL
    # Search strategies are part of the {wirings}, they find the next step
    # for an output.
    class Sequence
      class Search < Struct.new(:target_color)
        def call(sequence_ary, me)
          target_seq_row = find_target_sequence_row(sequence_ary, me)

          if target_seq_row
            target_node_id = target_seq_row.data.fetch(:id)

            raise if target_node_id != target_seq_row.node.id # FIXME: this is WIP, debugging
          else
            raise # FIXME: what to do in this case? we need to cover that for "unfinished" OPs.
          end

          return target_node_id
        end

        # Nil "search" is used for a terminal output, since it doesn't go anywhere
        # we can simply return nil as the {target_node_id}.
        # This is turn will indicate a terminus in the circuit.
        class Nil
          def call(sequence_ary, me)
            nil
          end
        end


        # From this task onwards, find the next task that's "magnetic to" {target_color}.
        # Note that we only go forward, no back-references are done here.
        class Forward < Search
          def find_target_sequence_row(sequence_ary, me)
            find_in_range(sequence_ary[sequence_ary.index(me) + 1..-1], target_color)
          end

          # @private
          def find_in_range(range, target_color)
            _target_seq_row = range.find { |seq_row| seq_row[0] == target_color }
          end
        end

        # Tries to find a track colored step by doing a Forward-search, first, then wraps around going
        # through all steps from sequence_ary start to self.
        class WrapAround < Forward
          def call(sequence_ary, me)
            my_index      = sequence_ary.index(me)
            # First, try all elements after me, then go through the elements preceding myself.
            wrapped_range = sequence_ary[my_index + 1..-1] + sequence_ary[0..my_index - 1]

            target_seq_row = find_in_range(wrapped_range, target_color)

            return target_seq_row
          end
        end

        # Find the seq_row with {id} and connect the current node to it.
        class ById < Forward
          def call(sequence_ary, me)
            target_seq_row = sequence_ary.find { |row| row.data.fetch(:id) == target_color } or return sequence_ary[0] # FIXME # or raise "Couldn't find {#{id}}"

            return target_seq_row
          end
        end
      end # Search
    end
  end
end
