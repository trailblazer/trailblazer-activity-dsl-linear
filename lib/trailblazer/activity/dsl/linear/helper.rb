module Trailblazer
  class Activity
    module DSL::Linear # TODO: rename!
      # @api private
      OutputSemantic = Struct.new(:value)
      Id             = Struct.new(:value)
      Track          = Struct.new(:color, :adds)
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

        seq = Linear.strip_start_and_ends(seq, end_id: _end_id) # don't cut off end unless {:connect_to} is set.

        if connect_to
          output, _ = seq[-1][2][0].(seq, seq[-1]) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h

          searches = [Linear::Search.ById(output, connect_to.value)]

          row = seq[-1]
          row = row[0..1] + [searches] + [row[3]] # FIXME: not mutating an array is so hard: we only want to replace the "searches" element, index 2

          seq = seq[0..-2] + [row]
        end

        # Add the path before End.success - not sure this is bullet-proof.
        adds = seq.collect do |row|
          {
            row:    row,
            insert: [Linear::Insert.method(:Prepend), "End.success"]
          }
        end

        # Connect the Output() => Track(path_track)
        return Track.new(track_color, adds)
      end

      # Computes the {:outputs} options for {activity}.
      def Subprocess(activity)
        {
          task:    activity,
          outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
        }
      end

      def normalize(options, local_keys) # TODO: test me.
        locals  = options.reject { |key, value| ! local_keys.include?(key) }
        foreign = options.reject { |key, value| local_keys.include?(key) }
        return foreign, locals
      end
    end
  end
end
