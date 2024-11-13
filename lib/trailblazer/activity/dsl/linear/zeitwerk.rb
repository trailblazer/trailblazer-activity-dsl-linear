module Trailblazer::Activity::DSL::Linear
  module Zeitwerk
    module Strategy
      # DISCUSS: rename to {Finalize}?
      # Don't recompile, just collect sequence steps.
      private def recompile_activity_for(type, *args, &block)
        sequence = apply_step_on_sequence_builder(type, *args, &block)

        @state.update!(:sequence) { |*| sequence }
      end

      # Compile the final {Activity} via the sequence.
      def finalize!
        sequence = @state.get(:sequence)
# puts "~~~~~~~~~ finalizing #{self.inspect}"
        recompile!(sequence)
      end
    end

    module DSL
      module Build
        module_function
        def Build(strategy, **options, &block)
          activity_class = super
puts "yoo"
          activity_class.finalize!

          activity_class
        end
      end

    end
  end # Zeitwerk
end
