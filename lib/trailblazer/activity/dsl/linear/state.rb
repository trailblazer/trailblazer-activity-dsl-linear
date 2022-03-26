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
        class State # TODO: rename to Dsl
          def self.build(normalizers:, initial_sequence:, fields: {}, **normalizer_options)
            tuples = {
              "sequence" =>       [initial_sequence, {}],
              "dsl/normalizer" =>          [normalizers, {}],  # copy on inherit
              "dsl/normalizer_options" => [normalizer_options, {}], # copy on inherit
              "fields" => [fields, {}],
            }

            state = Trailblazer::Declarative.State(tuples)

            new(state)
          end

            # remembers how to call normalizers (e.g. track_color), TaskBuilder
            # remembers sequence
          def initialize(state)
            @state = state
          end

          # Called to "inherit" a state.
          def copy # DISCUSS: this isn't DSL logic
            state = @state.copy

            self.class.new(state)
          end

          def to_h # DISCUSS: this isn't DSL logic
            {
              sequence: @state.get("sequence"),
              normalizers: @state.get("dsl/normalizer"),
              normalizer_options: @state.get("dsl/normalizer_options"),
              fields: @state.get("fields")
            } # DISCUSS: maybe {Declarative::State#to_h} could automatically provide this functionality?
          end

          def update_sequence(&block)
            @state.update!("sequence") do |sequence|
              yield(**to_h) # FIXME: define interface for block.
            end
          end

          def update_options(fields)
            @state.update!("fields") do |*|
              fields
            end
          end

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
