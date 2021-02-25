module Trailblazer
  class Activity
    module DSL
      module Linear
        # A {State} instance is kept per DSL client, which usually is a subclass of {Path}, {Railway}, etc.
        # State doesn't have any immutable features - all write operations to it must guarantee they only replace
        # instance variables.
        #
        # @private
        #
        # DISCUSS: why do we have this structure? It doesn't cover "immutable copying", that has to be done by its clients.
        #          also, copy with to_h
        class State
            # remembers how to call normalizers (e.g. track_color), TaskBuilder
            # remembers sequence
          def initialize(normalizers:, initial_sequence:, fields: {}.freeze, **normalizer_options)
            @normalizer         = normalizers # compiled normalizers.
            @sequence           = initial_sequence
            @normalizer_options = normalizer_options
            @fields             = fields
          end

          # Called to "inherit" a state.
          def copy
            self.class.new(normalizers: @normalizer, initial_sequence: @sequence, fields: @fields, **@normalizer_options)
          end

          def to_h
            {sequence: @sequence, normalizers: @normalizer, normalizer_options: @normalizer_options, fields: @fields} # FIXME.
          end

          def update_sequence(&block)
            @sequence = yield(**to_h)
          end

          def update_options(fields)
            @fields = fields
          end

          # Compiles and maintains all final normalizers for a specific DSL.
          class Normalizer
            def compile_normalizer(normalizer_sequence)
              process = Trailblazer::Activity::DSL::Linear::Compiler.(normalizer_sequence)
              process.to_h[:circuit]
            end

            # [gets instantiated at compile time.]
            #
            # We simply compile the activities that represent the normalizers for #step, #pass, etc.
            # This can happen at compile-time, as normalizers are stateless.
            def initialize(normalizer_sequences)
              @normalizers = Hash[
                normalizer_sequences.collect { |name, seq| [name, compile_normalizer(seq)] }
              ]
            end

            # Execute the specific normalizer (step, fail, pass) for a particular option set provided
            # by the DSL user. This is usually when you call Operation::step.
            def call(name, *args)
              normalizer = @normalizers.fetch(name)
              signal, (options, _) = normalizer.(*args)
              options
            end
          end
        end # State

      end
    end
  end
end
