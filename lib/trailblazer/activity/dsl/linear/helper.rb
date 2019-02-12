class Trailblazer::Activity
  module DSL::Linear # TODO: rename!
    # @api private
    OutputSemantic = Struct.new(:value)
    Id             = Struct.new(:value)
    Track          = Struct.new(:color)
    Extension      = Struct.new(:callable) do
      def call(*args, &block)
        callable.(*args, &block)
      end
    end

    # Shortcut functions for the DSL. These have no state.
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
      Track.new(color).freeze
    end

    def Id(id)
      Id.new(id).freeze
    end

    def Path(track_color: "track_#{rand}", end_semantic: track_color, **options, &block)
      raise block.inspect
      options = options.merge(track_color: track_color, end_semantic: end_semantic)

      # Build an anonymous class which will be where the block is evaluated in.
      # We use the same normalizer here, so DSL calls in the inner block have the same behavior.
      path = Module.new do
        extend Activity::Path( options.merge( normalizer: normalizer ) )
      end

      # this block is called in DSL::ProcessTuples. This could be improved somehow.
      ->(block) {
        path.instance_exec(&block)

        [ track_color, path ]
      }
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
