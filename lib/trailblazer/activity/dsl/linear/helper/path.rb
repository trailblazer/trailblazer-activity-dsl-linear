module Trailblazer
  class Activity
    module DSL
      module Linear
        module Helper
          # Normalizer logic for {Path() do ... end}.
          #
          # TODO: it would be cool to be able to connect an (empty) path to specific termini,
          #       this would work if we could add multiple magnetic_to.
          module Path
            # Normalizer steps to handle Path() macro.
            module Normalizer
              module_function

              # Replace a block-expecting {PathBranch} instance with another one that's holding
              # the global {:block} from {#step ... do end}.
              def forward_block_for_path_branch(ctx, flow_options, _, options:, normalizer_options:, **)
                block = options[:block]

                return ctx, flow_options unless block

                output, path_branch =
                  options.find { |output, cfg| cfg.is_a?(Linear::PathBranch) }

                path_branch_with_block = Linear::PathBranch.new(
                  normalizer_options
                    .merge(path_branch.options)
                    .merge(block: block)
                )

                ctx = ctx.merge(
                  options: ctx[:options].merge(output => path_branch_with_block)
                )

                return ctx, flow_options
              end

              # Convert all occurrences of Path() to a corresponding {Track}.
              # The {Track} instance contains all additional {adds} steps and
              # is picked up in {Normalizer.normalize_connections_from_dsl}.
              def convert_paths_to_tracks(ctx, flow_options, _, block: false, **)
                new_tracks = ctx
                  .find_all { |output, cfg| cfg.is_a?(Linear::PathBranch) }
                  .collect {  |output, cfg| [output, Path.convert_path_to_track(block: block, **cfg.options)]  }
                  .to_h

                ctx = ctx.merge(new_tracks)

                return ctx, flow_options
              end
            end # Normalizer

            module_function

            def convert_path_to_track(track_color: "track_#{rand}", connect_to: nil, before: false, block: nil, terminus: nil, **options)
              options =
                if connect_to
                  {}
                elsif terminus
                  options.merge(
                    end_task: Activity.End(terminus),
                    end_id:   "End.#{terminus}"
                  )
                else # Path() with End() inside block.
                  options
                end

              # DISCUSS:  if anyone overrides `#step` in the "outer" activity, this won't be applied inside the branch.

              # DISCUSS: use Path::Sequencer::Builder here instead?
              path = Activity::Path(**options, track_name: track_color, &block)

              seq = path.to_h[:sequence]
              seq = seq.to_a.to_h.values # strip off IDs. # FIXME: similar to when passing it to Compiler.

              # Strip default ends `Start.default` and `End.success` (if present).
              seq = seq[1..-1].reject { |row| row.data[:stop_event] && row.id == "End.success" }

              if connect_to
                seq = connect_for_sequence(seq, connect_to: connect_to)
              end

              # Add the path elements before {End.success}.
              # Termini (or :stop_event) are to be placed after {End.success}.
              adds = seq.collect do |row|
                # the terminus of the path goes _after_ {End.success} into the "end group".
                insert_method = row.data[:stop_event] ? :append : :prepend

                insert_target = "End.success" # insert before/after
                insert_target = before if before && connect_to.instance_of?(Linear::Normalizer::OutputTuples::Track) # FIXME: this is a bit hacky, of course!

                # ADDS friendly interface:
                [
                  row, id: row.id, insert_method => insert_target
                ]
              end

              # Connect the Output() => Track(path_track)
              Linear::Normalizer::OutputTuples::Track.new(track_color, adds, {})
            end

            # Connect last row of the {sequence} to the given step via its {Id}
            # Useful when steps needs to be inserted in between {Start} and {connect Id()}.
            private def connect_for_sequence(sequence, connect_to:)
              last_step_on_path = sequence[-1]
              output_searches   = last_step_on_path[2]

              last_step_outputs =
                output_searches.collect do |search_strategy|
                  # TODO: introduce {search_strategy.to_h} so we don't need to execute it here.
                  output, _ = search_strategy.(sequence, last_step_on_path) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h
                  output
                end

              # we want to reconnect the last step's {:success} output, everything else we keep.
              success_output = last_step_outputs.find { |output| output.to_h[:semantic] == :success } or raise

                # FIXME: what about End()?
              success_search = Sequence::Search.ById(success_output, connect_to.value) if connect_to.instance_of?(Linear::Normalizer::OutputTuples::Id)
              success_search = Sequence::Search.Forward(success_output, connect_to.color) if connect_to.instance_of?(Linear::Normalizer::OutputTuples::Track) # FIXME: use existing mapping logic!

              success_output_index = last_step_outputs.index(success_output)

              output_searches[success_output_index] = success_search # replace the success search strategy. # DISCUSS: a bit cryptical with this index.

              row_options = last_step_on_path.to_h.merge(wirings: output_searches)
              row = Sequence.Row(**row_options)

              sequence[0..-2] + [row]
            end
          end # Path
        end
      end
    end
  end
end
