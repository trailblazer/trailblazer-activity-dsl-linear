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

            return new(state), initial_sequence
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

          # @private
          def update_sequence!(&block)
            @state.update!("sequence") do |sequence|
              yield(**to_h) # FIXME: define interface for block.
            end
          end

          # FIXME: move me to Strategy
          def update_options!(fields)
            @state.update!("fields") do |*|
              fields
            end
          end

          # Called from {#step} and friends in the {Strategy} subclass.
          # Used to be named {Strategy.task_for!}.
          # Top-level entry point for "adding a step".
          def update_sequence_for!(type, *args, &block)
            # {#update_sequence!} is the only way to mutate the state instance.
            update_sequence! do |sequence:, normalizers:, normalizer_options:, **|
              # Compute the sequence rows.
              self.class.update_sequence_for(type, *args, normalizers: normalizers, normalizer_options: normalizer_options, sequence: sequence, &block)
            end
          end

          # Run a specific normalizer (e.g. for `#step`), apply the adds to the sequence and return the latter.
          # DISCUSS: where does this method belong? Sequence + Normalizers?
          def self.update_sequence_for(type, task, options={}, sequence:, **kws, &block)
            step_options = invoke_normalizer_for(type, task, options, sequence: sequence, **kws, &block)

            _sequence = Linear::Sequence.apply_adds(sequence, step_options[:adds])
          end

          def self.invoke_normalizer_for(type, task, options, normalizers:, normalizer_options:, sequence:, &block)
            options = options.merge(
              dsl_track:   type,
              block:       block,
              normalizers: normalizers # DISCUSS: do we need you?
            )

            _step_options = normalizers.(type, normalizer_options: normalizer_options, options: task, user_options: options.merge(sequence: sequence))
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
