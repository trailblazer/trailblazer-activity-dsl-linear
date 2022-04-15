module Trailblazer
  class Activity
    module DSL
      module Linear
        module Helper
          # Normalizer logic for {Path() do end}.
          #
          # TODO: it would be cool to be able to connect an (empty) path to specific termini,
          #       this would work if we could add multiple magnetic_to.
          module Path
            # Normalizer steps to handle Path() macro.
            module Normalizer
              module_function
              # Forward the block to the DSL's {PathBranch} instance.
              #   step ..., Output(:semantic) => Path() do .. end
              #
              # Replace a block-expecting {PathBranch} instance with another one that's holding
              # the global {:block} from {#step}.
              def forward_block_for_path_branch(ctx, non_symbol_options:, block: false, **)
                return unless block

                output, path_branch =
                  non_symbol_options.find { |output, cfg| cfg.kind_of?(Linear::PathBranch) }

                path_branch_with_block = Linear::PathBranch.new(path_branch.options.merge(block: block)) # DISCUSS: lots of internal knowledge here.

                ctx[:non_symbol_options] = non_symbol_options.merge(output => path_branch_with_block)
              end

              # Convert all occurrences of Path() to a corresponding {Track}.
              # The {Track} instance contains all additional {adds} steps and
              # is picked up in {Normalizer.normalize_connections_from_dsl}.
              def convert_paths_to_tracks(ctx, non_symbol_options:, block: false, **)
                new_tracks = non_symbol_options.
                  find_all { |output, cfg| cfg.kind_of?(Linear::PathBranch) }.
                  collect {  |output, cfg| [output, Path.convert_path_to_track(block: ctx[:block], **cfg.options)]  }.
                  to_h

                ctx[:non_symbol_options] = non_symbol_options.merge(new_tracks)
              end
            end # Normalizer

            module_function

            def convert_path_to_track(track_color: "track_#{rand}", connect_to: nil, before: false, block: nil, **options)
              # DISCUSS: should we inherit from self here and erase sequence?
              #   if anyone overrides `#step` in the "outer" activity, this won't be applied inside the branch.
              path_state = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState(**options, track_name: track_color))
              path_state.instance_exec(&block)

              seq = path_state.to_h[:sequence]
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
                insert_target = before if before && connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Track) # FIXME: this is a bit hacky, of course!

                {
                  row:    row,
                  insert: [insert_method, insert_target]
                }
              end

              # Connect the Output() => Track(path_track)
              return Linear::Track.new(track_color, adds, {})
            end

            # Connect last row of the {sequence} to the given step via its {Id}
            # Useful when steps needs to be inserted in between {Start} and {connect Id()}.
            private def connect_for_sequence(sequence, connect_to:)
              output, _ = sequence[-1][2][0].(sequence, sequence[-1]) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h

              # searches = [Search.ById(output, connect_to.value)]
              searches = [Search.ById(output, connect_to.value)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Id)
              searches = [Search.Forward(output, connect_to.color)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Track) # FIXME: use existing mapping logic!

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
