module Trailblazer
  class Activity
    module DSL
      module Feature
        # Depends on Feature::OutputTuples.
        class Path < Struct.new(:options)
          module Helper
            def Path(**options)
              options = {
                exec_context: config.builder.default_options.fetch(:step).fetch(:exec_context)
              }.merge(options)

              Path.new(options)
            end
          end

          # FIXME: we're defauting adds_for_sequence, which is redundant, see DSL::Normalizer::Step.
          def call(block_arg: -> {}, adds_for_sequence: [], **ctx) # This is called in OutputTuples::Normalizer#
            build_path(block_arg: block_arg, **options)
          end

          def build_path(track_color: "track_#{rand}", connect_to: nil, before: false, block_arg:, terminus: nil, exec_context:, **options)
            options =
              if connect_to
                {}
              elsif terminus
                options.merge(
                  end_task: Activity::Path.send(:Terminus, terminus),
                  # end_id:   "End.#{terminus}"
                )
              else # Path() with End() inside block.
                options
                # FIXME: should we remove this?
              end

            # DISCUSS:  if anyone overrides `#step` in the "outer" activity, this won't be applied inside the branch.
            activity, builder = Activity.Path(exec_context: exec_context, &block_arg)

            seq = builder.sequence
            seq = seq.to_a.to_h # FIXME: introduce canonical way to work on Sequence.


            # Strip default ends `Start.default` and `End.success` (if present).
            seq = seq.reject { |id, _| id == :"End.success" }
            pp seq

            if connect_to
              seq = connect_for_sequence(seq, connect_to: connect_to)
            end

            # Add the path elements before {End.success}.
            # Termini (or :stop_event) are to be placed after {End.success}.
            adds_for_path = seq.collect do |id, row|
              # the terminus of the path goes _after_ {End.success} into the "end group".
              # insert_method = row.data[:stop_event] ? :append : :prepend
              insert_method = :after

              insert_target = :"End.success" # insert before/after
         # insert_target = before if before && connect_to.instance_of?(Linear::Normalizer::OutputTuples::Track) # FIXME: this is a bit hacky, of course!

              # ADDS friendly interface:
              [
                id, row, insert_method, insert_target
              ]
            end

            # Connect the Output() => Track(path_track)
            # Linear::Normalizer::OutputTuples::Track.new(track_color, adds, {})

            return OutputTuples::Target::Track.new(track_color, adds_for_path, {}).()
          end

          # # module Path
          # #   # Normalizer steps to handle Path() macro.
          # #   module Normalizer
          # #     module_function

          # #     # Replace a block-expecting {PathBranch} instance with another one that's holding
          # #     # the global {:block} from {#step ... do end}.
          # #     def forward_block_for_path_branch(ctx, flow_options, _, block:, normalizer_options:, **)
          # #       return ctx, flow_options unless block

          # #       output, path_branch =
          # #         ctx.find { |output, cfg| cfg.is_a?(Linear::PathBranch) }

          # #       path_branch_with_block = Linear::PathBranch.new(
          # #         normalizer_options
          # #           .merge(path_branch.options)
          # #           .merge(block: block)
          # #       )

          # #       ctx = ctx.merge(
          # #         output => path_branch_with_block
          # #       )

          # #       return ctx, flow_options
          # #     end

          #     # Convert all occurrences of Path() to a corresponding {Track}.
          #     # The {Track} instance contains all additional {adds} steps and
          #     # is picked up in {Normalizer.normalize_connections_from_dsl}.
          #     def convert_paths_to_tracks(ctx, flow_options, _, block: false, **)
          #       new_tracks = ctx
          #         .find_all { |output, cfg| cfg.is_a?(Linear::PathBranch) }
          #         .collect {  |output, cfg| [output, Path.convert_path_to_adds(block: block, **cfg.options)]  }
          #         .to_h

          #       ctx = ctx.merge(new_tracks)

          #       return ctx, flow_options
          #     end
          #   end # Normalizer



          # Connect last row of the {sequence} to the given step via its {Id}
          # Useful when steps needs to be inserted in between {Start} and {connect Id()}.
          private def connect_for_sequence(sequence, connect_to:)
            termini = sequence.find_all { |row| row.data[:stop_event] }
            user_steps = sequence - termini

            last_step_on_path = user_steps[-1]
            output_2_search   = last_step_on_path[2]
# pp last_step_on_path

            # we want to reconnect the last step's {:success} output, everything else we keep.
            success_output,  _ = output_2_search  .find { |output, _| output.to_h[:semantic] == :success }
            raise if success_output.nil?

              # FIXME: what about End()?
            success_search = Sequence::Search::ById.new(connect_to.value) if connect_to.instance_of?(Linear::Normalizer::OutputTuples::Id)
            success_search = Sequence::Search::Forward.new(connect_to.color) if connect_to.instance_of?(Linear::Normalizer::OutputTuples::Track) # FIXME: use existing mapping logic!

            output_2_search[success_output] = success_search # replace the success search strategy.

            row_options = last_step_on_path.to_h.merge(wirings: output_2_search)
            row = Sequence.Row(**row_options)

            user_steps[0..-2] + [row] + termini
          end # Path
        end
      end
    end
  end
end
