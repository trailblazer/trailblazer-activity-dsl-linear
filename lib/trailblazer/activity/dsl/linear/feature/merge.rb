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
        def self.call(old_seq, new_seq, end_id: "End.success") # DISCUSS: also Insert
          new_seq = strip_start_and_ends(new_seq, end_id: end_id)

          _seq = Adds.apply_adds(
            old_seq,
            new_seq.collect { |row| {insert: [Adds::Insert.method(:Prepend), end_id], row: row} }
          )
        end

        def self.strip_start_and_ends(seq, end_id:)
          cut_off_index = end_id.nil? ? seq.size : Adds::Insert.find_index(seq, end_id) # find the "first" end.

          seq[1..cut_off_index - 1]
        end
      end # Merge
    end
  end
end
