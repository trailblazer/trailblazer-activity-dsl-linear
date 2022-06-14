module Trailblazer
  class Activity
    module DSL
      module Linear
        module Sequencer
          # @return Sequence
          def self.call(method, argument, options, **kws, &block)
            update_sequence_for(method, argument, options, **kws, &block)
          end

          # @private
          # Run a specific normalizer (e.g. for `#step`), apply the adds to the sequence and return the latter.
          # DISCUSS: where does this method belong? Sequence + Normalizers?
          def self.update_sequence_for(type, task, options={}, sequence:, **kws, &block)
            step_options = invoke_normalizer_for(type, task, options, sequence: sequence, **kws, &block)

            _sequence = Activity::Adds.apply_adds(sequence, step_options[:adds])
          end

          # @private
          # DISCUSS: used in {Normalizer#add_terminus}, too.
          def self.invoke_normalizer_for(type, task, options, normalizers:, normalizer_options:, sequence:, &block)
            # These options represent direct configuration of the very method call that causes the normalizer to be run.
            library_options = {
              dsl_track:   type,
              block:       block,

              # DISCUSS: for some reason I am not entirely happy with those variables being here. Maybe this will change.
              normalizers: normalizers,
              sequence:    sequence,
            }

            _step_options = normalizers.(type,
              normalizer_options: normalizer_options, # class-level Strategy configuration, such as :step_interface_builder
              options:            task,               # macro-options
              user_options:       options,            # user-specified options from the DSL method
              library_options:    library_options     # see above, "runtime" options (from compile-time, haha).
            )
          end
        end # Sequencer
      end
    end
  end
end
