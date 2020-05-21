module Trailblazer
  class Activity
    module DSL
      module Linear
        module Helper
          # @api private
          OutputSemantic = Struct.new(:value)
          Id             = Struct.new(:value)
          Track          = Struct.new(:color, :adds)
          Extension      = Struct.new(:callable) do
            def call(*args, &block)
              callable.(*args, &block)
            end
          end

          def self.included(base)
            base.extend ClassMethods
          end

          # Shortcut functions for the DSL.
          module ClassMethods
            #   Output( Left, :failure )
            #   Output( :failure ) #=> Output::Semantic
            def Output(signal, semantic=nil)
              return OutputSemantic.new(signal) if semantic.nil?

              Activity.Output(signal, semantic)
            end

            def End(semantic)
              Activity.End(semantic)
            end

            def end_id(_end)
              "End.#{_end.to_h[:semantic]}" # TODO: use everywhere
            end

            def Track(color)
              Track.new(color, []).freeze
            end

            def Id(id)
              Id.new(id).freeze
            end

            def Path(track_color: "track_#{rand}", end_id:"path_end_#{rand}", connect_to:nil, **options, &block)
              # DISCUSS: here, we use the global normalizer and don't allow injection.
              state = Activity::Path::DSL::State.new(Activity::Path::DSL.OptionsForState(track_name: track_color, end_id: end_id, **options)) # TODO: test injecting {:normalizers}.

              # seq = block.call(state) # state changes.
              state.instance_exec(&block)

              seq = state.to_h[:sequence]

              _end_id =
                if connect_to
                  end_id
                else
                  nil
                end

              seq = strip_start_and_ends(seq, end_id: _end_id) # don't cut off end unless {:connect_to} is set.

              if connect_to
                output, _ = seq[-1][2][0].(seq, seq[-1]) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h

                searches = [Search.ById(output, connect_to.value)]

                row = seq[-1]
                row = row[0..1] + [searches] + [row[3]] # FIXME: not mutating an array is so hard: we only want to replace the "searches" element, index 2

                seq = seq[0..-2] + [row]
              end

              # Add the path before End.success - not sure this is bullet-proof.
              adds = seq.collect do |row|
                {
                  row:    row,
                  insert: [Insert.method(:Prepend), "End.success"]
                }
              end

              # Connect the Output() => Track(path_track)
              return Track.new(track_color, adds)
            end

            # Computes the {:outputs} options for {activity}.
            def Subprocess(activity, patch: {})
              activity = Patch.customize(activity, options: patch)

              {
                task:    activity,
                outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
              }
            end

            module Patch
              module_function

              def customize(activity, options:)
                options = options.is_a?(Proc) ?
                  { [] => options } : # hash-wrapping with empty path, for patching given activity itself
                  options

                options.each do |path, patch|
                  activity = call(activity, path, patch) # TODO: test if multiple patches works!
                end

                activity
              end

              def call(activity, path, customization)
                task_id, *path = path

                patch =
                  if task_id
                    segment_activity = Introspect::Graph(activity).find(task_id).task
                    patched_segment_activity = call(segment_activity, path, customization)

                    # Replace the patched subprocess.
                    -> { step Subprocess(patched_segment_activity), replace: task_id, id: task_id }
                  else
                    customization # apply the *actual* patch from the Subprocess() call.
                  end

                patched_activity = Class.new(activity)
                patched_activity.class_exec(&patch)
                patched_activity
              end
            end

            def normalize(options, local_keys) # TODO: test me.
              locals  = options.reject { |key, value| ! local_keys.include?(key) }
              foreign = options.reject { |key, value| local_keys.include?(key) }
              return foreign, locals
            end
          end
        end # Helper

        include Helper # Introduce Helper constants in DSL::Linear scope
      end # Linear
    end # DSL
  end # Activity
end
