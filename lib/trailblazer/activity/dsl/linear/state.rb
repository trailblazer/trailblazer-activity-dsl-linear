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
          def self.invoke_normalizer_for(type, task, options, normalizers:, normalizer_options:, sequence:, &block)
            options = options.merge(
              dsl_track:   type,
              block:       block,
              normalizers: normalizers # DISCUSS: do we need you?
            )

            _step_options = normalizers.(type, normalizer_options: normalizer_options, options: task, user_options: options.merge(sequence: sequence))
          end
        end

        # A {State} instance is kept per DSL client, which usually is a subclass of {Path}, {Railway}, etc.
        # State doesn't have any immutable features - all write operations to it must guarantee they only replace
        # instance variables.
        #
        # @private
        #
        # DISCUSS: why do we have this structure? It doesn't cover "immutable copying", that has to be done by its clients.
        #          also, copy with to_h
        #
        # * All public DSL methods on Sequencer return the updated sequence.
        class State # TODO: rename to Sequencer::Builder


          # Compiles and maintains all final normalizers for a specific DSL.
          class Normalizer
            # [gets instantiated at compile time.]
            #
            # We simply compile the activities that represent the normalizers for #step, #pass, etc.
            # This can happen at compile-time, as normalizers are stateless.
            def initialize(normalizer_pipelines)
              @normalizers = normalizer_pipelines
            end

            # Execute the specific normalizer (step, fail, pass) for a particular option set provided
            # by the DSL user. This is usually when you call Operation::step.
            def call(name, ctx)
              normalizer = @normalizers.fetch(name)
              wrap_ctx, _ = normalizer.(ctx, nil)
              wrap_ctx
            end
          end
        end # State

      end
    end
  end
end
