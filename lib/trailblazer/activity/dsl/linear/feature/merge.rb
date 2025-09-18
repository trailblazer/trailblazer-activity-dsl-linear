class Trailblazer::Activity
  module DSL
    module Linear
      module Merge
        # Class methods for {Strategy}.
        module DSL
          def merge!(activity)
            old_seq = to_h[:sequence]
            new_seq = activity.to_h[:sequence]

            seq = Merge.call(old_seq, new_seq, end_id: "End.success")

            # Update the DSL's sequence, then recompile the actual activity.
            recompile!(seq)
          end
        end

        # Compile-time logic to merge two activities.
        def self.call(old_seq, new_seq, start_id: "Start.default", end_id: "End.success") # DISCUSS: also Insert
          new_seq = strip_start_and_ends(new_seq, start_id: start_id, end_id: end_id)

          Adds.(
            old_seq,
            *new_seq.to_h.collect { |id, row| [row, id: id, prepend: end_id] }
          )
        end

        def self.strip_start_and_ends(sequence, start_id:, end_id:)
          Adds.(
            sequence,
            [nil, id: nil, delete: start_id],
            [nil, id: nil, delete: end_id],
          )
        end
      end # Merge
    end
  end
end
