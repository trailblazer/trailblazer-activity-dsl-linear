module Trailblazer
  class Activity
    module DSL
      module Linear
        module Helper
          # Normalizer logic for {Path() do end}.
          module Path
            module_function

            def convert_path_to_track(track_color: "track_#{rand}", connect_to: nil, before: false, block: nil, **options)
              path      = Activity::Path(**options, track_name: track_color)
              activity  = Class.new(path) { self.instance_exec(&block) }

              seq = activity.instance_variable_get(:@state).to_h[:sequence] # TODO: fix @state interface
              # Strip default ends `Start.default` and `End.success` (if present).
              seq = seq[1..-1].reject{ |row| row[3][:stop_event] && row[3][:id] == 'End.success' }

              if connect_to
                seq = connect_for_sequence(seq, connect_to: connect_to)
              end

              # Add the path elements before {End.success}.
              # Termini (or :stop_event) are to be placed after {End.success}.
              adds = seq.collect do |row|
                options = row[3]

                # the terminus of the path goes _after_ {End.success} into the "end group".
                insert_method = options[:stop_event] ? Insert.method(:Append) : Insert.method(:Prepend)

                insert_target = "End.success" # insert before/after
                insert_target = before if before && connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Helper::Track) # FIXME: this is a bit hacky, of course!

                {
                  row:    row,
                  insert: [insert_method, insert_target]
                }
              end

              # Connect the Output() => Track(path_track)
              return Linear::Helper::Track.new(track_color, adds, {})
            end

            # Connect last row of the {sequence} to the given step via its {Id}
            # Useful when steps needs to be inserted in between {Start} and {connect Id()}.
            private def connect_for_sequence(sequence, connect_to:)
              output, _ = sequence[-1][2][0].(sequence, sequence[-1]) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h

              # searches = [Search.ById(output, connect_to.value)]
              searches = [Search.ById(output, connect_to.value)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Helper::Id)
              searches = [Search.Forward(output, connect_to.color)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Helper::Track) # FIXME: use existing mapping logic!

              row = sequence[-1]
              row = row[0..1] + [searches] + [row[3]] # FIXME: not mutating an array is so hard: we only want to replace the "searches" element, index 2

              sequence = sequence[0..-2] + [row]

              sequence
            end
          end # Path
        end
      end
    end
  end
end