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
          def call(block_arg: -> {}, adds_for_sequence: [], sequence:, **ctx) # This is called in OutputTuples::Normalizer#
            build_path(block_arg: block_arg, sequence: sequence, **options)
          end

          # TODO: deprecate {:terminus} etc.
          def build_path(track_name: "track_#{rand}", connect_to:, block_arg:, exec_context:, **options)
            # DISCUSS:  if anyone overrides `#step` in the "outer" activity, this won't be applied inside the branch.
            _block_arg = -> {
              extend Trailblazer::Activity::DSL::Topology::Helper
              instance_exec(&block_arg)
            }
            activity, builder = Activity.Path(track_name: track_name, exec_context: exec_context, &_block_arg)

            seq = builder.sequence
            seq = seq.to_a.to_h # FIXME: introduce canonical way to work on Sequence.

            # Strip default terminus `End.success` (if present).
            seq = seq.reject { |id, _| id == :"End.success" }

            # Rewire the last step.
            last_step_id = seq.keys.last
            last_step = seq[last_step_id]

            adds_for_path = []

            if connect_to
              new_wirings = last_step.wirings.collect do |output, target|
                search, adds_from_target = connect_to.(**options)

                adds_for_path += adds_from_target

                [output, search]
              end.to_h

              adds_for_path = adds_for_path.collect { |(id, *row)| [id, [id, *row]] }.to_h
              adds_for_path = adds_for_path.values # filter out double entries eg. Terminus(:received) for two outputs.

              last_step.wirings = new_wirings # DISCUSS: mutability?
              seq[last_step_id] = last_step
            end

            # Add the path elements before {End.success}.
            # Termini (or :stop_event) are to be placed after {End.success}.
            adds_for_path += seq.collect do |id, row|
              [id, row, :before, :"End.success"]
            end

            # Connect the Output() => Track(path_track)
            return OutputTuples::Target::Track.new(track_name, adds_for_path , {}).()
          end
        end
      end
    end
  end
end
