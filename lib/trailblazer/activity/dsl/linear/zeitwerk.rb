module Trailblazer::Activity::DSL::Linear
  module Zeitwerk
    module Strategy
      private def recompile_activity_for(type, *args, &block)
        sequence = apply_step_on_sequence_builder(type, *args, &block)

        @state.update!(:sequence) { |*| sequence }
      end

      def finalize!
        sequence = @state.get(:sequence)

        recompile!(sequence)
      end
    end
  end
end
