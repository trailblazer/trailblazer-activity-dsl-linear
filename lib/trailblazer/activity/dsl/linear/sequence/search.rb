class Trailblazer::Activity
  module DSL
    module Linear
      # Search strategies are part of the {wirings}, they find the next step
      # for an output.
      class Sequence
        module Search
          module_function

          # From this task onwards, find the next task that's "magnetic to" {target_color}.
          # Note that we only go forward, no back-references are done here.
          def Forward(output, target_color)
            ->(sequence, me) do
              target_seq_row = find_in_range(sequence[sequence.index(me) + 1..-1], target_color)

              return output, target_seq_row
            end
          end

          # Tries to find a track colored step by doing a Forward-search, first, then wraps around going
          # through all steps from sequence start to self.
          def WrapAround(output, target_color)
            ->(sequence, me) do
              my_index      = sequence.index(me)
              # First, try all elements after me, then go through the elements preceding myself.
              wrapped_range = sequence[my_index + 1..-1] + sequence[0..my_index - 1]

              target_seq_row = find_in_range(wrapped_range, target_color)

              return output, target_seq_row
            end
          end

          def Noop(output)
            ->(sequence, me) do
              return output, [nil, nil, nil, {}] # FIXME
            end
          end

          # Find the seq_row with {id} and connect the current node to it.
          def ById(output, id)
            ->(sequence, me) do
              index          = Adds::Insert.find_index(sequence, id) or return output, sequence[0] # FIXME # or raise "Couldn't find {#{id}}"
              target_seq_row = sequence[index]

              return output, target_seq_row
            end
          end

          # @private
          def find_in_range(range, target_color)
            _target_seq_row = range.find { |seq_row| seq_row[0] == target_color }
          end
        end # Search
      end
    end
  end
end
