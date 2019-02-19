class Trailblazer::Activity
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
      Trailblazer::Activity.End(semantic)
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

    def Path(track_color: "track_#{rand}", end_id:, **options, &block)
      # DISCUSS: here, we use the global normalizer and don't allow injection.
      state = Trailblazer::Activity::Path::DSL::State.new(Trailblazer::Activity::Path::DSL.OptionsForState(track_name: track_color, end_id: end_id, **options)) # TODO: test injecting {:normalizers}.

      seq = block.call(state) # state changes.

      seq = Linear.strip_start_and_ends(seq, end_id: nil) # don't cut off end

      # Add the path before End.success - not sure this is bullet-proof.
      insert_rows = seq.collect do |row|
        [row, Linear::Insert.method(:Prepend), "End.success"]
      end

      return Track.new(track_color, insert_rows)
    end

    # Computes the :outputs options for {activity}
    def Subprocess(activity)
      {
        task:    activity,
        outputs: activity.outputs
      }
    end

    def normalize(options, local_keys) # TODO: test me.
      locals  = options.reject { |key, value| ! local_keys.include?(key) }
      foreign = options.reject { |key, value| local_keys.include?(key) }
      return foreign, locals
    end
  end
end
