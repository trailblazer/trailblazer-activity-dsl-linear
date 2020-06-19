module Trailblazer
  class Activity
    module DSL::Linear # TODO: rename!
      # @api private
      OutputSemantic = Struct.new(:value)
      Id             = Struct.new(:value)
      Track          = Struct.new(:color, :adds, :options)
      Extension      = Struct.new(:callable) do
        def call(*args, &block)
          callable.(*args, &block)
        end
      end

      # Shortcut functions for the DSL.
      module_function

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

      def Track(color, wrap_around: false)
        Track.new(color, [], wrap_around: wrap_around).freeze
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
        return Track.new(track_color, adds, {}) # TODO: use Helper::Track.
      end

      # Computes the {:outputs} options for {activity}.
      def Subprocess(activity, patch: {})
        patch.each do |path, patch|
          activity = Patch.(activity, path, patch) # TODO: test if multiple patches works!
        end

        {
          task:    activity,
          outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
        }
      end

      module Patch
        module_function

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
  end
end
