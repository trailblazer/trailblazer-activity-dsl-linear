module Trailblazer
  class Activity
    module DSL
      module Linear
        # {Activity}
        #   holds the {@schema}
        #   provides DSL step/merge!
        #   provides DSL inheritance
        #   provides run-time {call}
        #   maintains the {state} with {seq} and normalizer options
        class Strategy
          extend Linear::Helper # import {Subprocess()} and friends as class methods. creates shortcuts to {Strategy.Output} etc.
          include Linear::Helper::Constants

          class << self
            def initialize!(state)
              @state = state
            end

            def inherited(inheriter)
              super

              # Inherits the {State:sequencer} and other options without recomputing anything.
              inheriter.initialize!(@state.copy)
            end

            # @public
            # We forward `step` to the Dsl (State) object.
            # Recompiling the activity/sequence is a matter specific to Strategy (Railway etc).
            def step(*args, &block)
              recompile_activity_for(:step, *args, &block)
            end

            def terminus(*args)
              recompile_activity_for(:terminus, *args)
            end

            private def recompile_activity_for(type, *args, &block)
              sequence = apply_step_on_sequence_builder(type, *args, &block)

              recompile!(sequence)
            end

            # TODO: make {rescue} optional, only in dev mode.
            # @return Sequence
            private def apply_step_on_sequence_builder(type, arg, options = {}, &block)
              Sequence::Builder.(type, arg, options,
                sequence:           @state.get(:sequence),
                normalizers:        @state.get(:normalizers),

                normalizer_options: @state.get(:normalizer_options),

                &block)
            rescue Activity::Adds::IndexError
              # re-raise this exception with activity class prepended
              # to the message this time.
              raise $!, "#{self}:#{$!.message}"
            end

            private def recompile_activity(sequence)
              # Transform the {Sequence < Pipeline} to an array of row which the Compiler understands.
              sequence = sequence.to_h.values

              schema = Sequence::Compiler.(sequence)

              Activity.new(schema)
            end

            # DISCUSS: this should be the only way to "update" anything on state.
            def recompile!(sequence)
              activity = recompile_activity(sequence)

              @state.update!(:sequence) { |*| sequence }
              @state.update!(:activity) { |*| activity }
            end

            # Used only once per strategy class body.
            def compile_strategy!(strategy_dsl, **options)
              sequence = initialize_options!(strategy_dsl) # sets @sequence.
              recompile!(sequence)
            end

            def compile_strategy_for!(sequence:, normalizers:, **normalizer_options)
              @state.update!(:normalizers)        { normalizers }        # immutable
              @state.update!(:normalizer_options) { normalizer_options } # immutable

              recompile!(sequence)
            end

            # Logic for creating a new Strategy type.
            module Build
              # module_function

              # def call(strategy_class, options_from_strategy = )

              # end
            end

            # This is logic done only once, when creating a new Strategy base type.
            def initialize_options!(strategy_class, user_options_to_merge = {}, options_from_strategy = strategy_class.options_for_build(**user_options_to_merge),
                normalizers:          options_from_strategy.fetch(:normalizers),
                normalizer_options:   options_from_strategy.fetch(:normalizer_options),
                layout_instructions:  options_from_strategy.fetch(:layout_instructions)
              )

              # normalizer_options = normalizer_options.merge(normalizer_options_to_merge) # FIXME: is this properly tested?
              pp normalizer_options

              @state.update!(:normalizers) { normalizers }
              @state.update!(:normalizer_options) { normalizer_options }
              @state.update!(:sequence) { [] }

              # Add start and termini. This will only change @state{:sequence}
              layout_instructions.each do |dsl_method, options|
                # puts "@@@@@ #{dsl_method.inspect} #{options}"
                send(dsl_method, options)
              end

              @state.get(:sequence)
            end

            # Mainly used for introspection.
            def to_h
              activity = @state.get(:activity)

              activity.to_h.to_h.merge(
                activity: activity,
                sequence: @state.get(:sequence), # DISCUSS: do we need this structure after compile time?
                fields:   @state.get(:fields)
              )
            end

            # @Runtime
            # Injects {:exec_context} so that {:instance_method}s work.
            def call(ctx, flow_options, circuit_options)
              activity = @state.get(:activity)

              activity.(
                ctx,
                flow_options,
                circuit_options.merge(exec_context: new)
              )
            end

            def invoke(*args, **kws)
              TaskWrap.invoke(self, *args, **kws)
            end
          end # class << self

          module DSL
            module_function

            def Build(strategy, options, &block)
              Class.new(strategy) do
                # compile_strategy!(strategy::DSL, **options)
                sequence = initialize_options!(strategy::DSL, options) # sets @sequence.
                recompile!(sequence)

                class_exec(&block) if block
              end
            end

          end # DSL

          # FIXME: move to State#dup
          def self.copy(value, **) # DISCUSS: should that be here?
            value.copy
          end

          require_relative "feature/merge"
          extend Merge::DSL # {Strategy.merge!}

          def self.normalizer_ext_for_initial_task_wrap(ctx, **)
            id, task = Activity::TaskWrap::ROW_ARGS_FOR_CALL_TASK

            # As this Extension should be the first to be executed, we need to merge the existing last.
            {Strategy.Extension(is_generic: true) => TaskWrap.Extension([task, id: id, prepend: nil])}
              .merge(ctx)
          end

          state = Declarative::State(
            normalizers: [nil, {}],        # immutable
            normalizer_options: [nil, {}], # immutable

            sequence:  [nil, {}], # when inherited, call #dup
            activity:  [nil, {}], # when inherited, call #dup

            fields:    [Hash.new, {}],
          )

          initialize!(state) # build an empty State instance that can be copied and recompiled.

          # DISCUSS: where to move this?
          # This is taskWrap specific logic that might be used by {Invoke}.
          INITIAL_NORMALIZER_EXTENSIONS = [
            method(:normalizer_ext_for_initial_task_wrap)
          ].freeze

          state.update!(:fields) do |fields|
            fields.merge(
              normalizer_extensions: INITIAL_NORMALIZER_EXTENSIONS # this will be the taskWrap used when being nested, to the composing activity, for "us".
            )
          end

          # This is done in every subclass.
          # recompile!([]) # DISCUSS: DO WE NEED IT?
        end # Strategy
      end
    end
  end
end
