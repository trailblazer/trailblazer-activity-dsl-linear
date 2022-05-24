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
        # This could be a class but we decided to leave it as a module that then gets
        # extended into {Path} and friends. This won't trigger the inheritance (because)
        # there is nothing to inherit.
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
            def step(*args, &block); recompile_activity_for(:step, *args, &block); end
            def terminus(*args);     recompile_activity_for(:terminus, *args); end

            private def recompile_activity_for(type, *args, &block)
              sequence = apply_step_on_sequencer(type, *args, &block)

              recompile!(sequence)
            end

            # TODO: make {rescue} optional, only in dev mode.
            # @return Sequence
            private def apply_step_on_sequencer(type, arg, options={}, &block)
              return Sequencer.(type, arg, options,
                sequence:           @state.get(:sequence),
                normalizers:        @state.get(:normalizers),

                normalizer_options: @state.get(:normalizer_options),

                 &block
              )

            rescue Sequence::IndexError
              # re-raise this exception with activity class prepended
              # to the message this time.
              raise $!, "#{self}:#{$!.message}"
            end

            private def recompile_activity(sequence)
              schema = Compiler.(sequence)
              Activity.new(schema)
            end

            # DISCUSS: this should be the only way to "update" anything on state.
            def recompile!(sequence)
              activity = recompile_activity(sequence)

              @state.update!(:sequence) { |*| sequence }
              @state.update!(:activity) { |*| activity }
            end

            # Used only once per strategy class body.
            def compile_strategy!(strategy, **options)
              options = strategy.OptionsForSequencer(**options)

              compile_strategy_for!(**options)
            end

            def compile_strategy_for!(sequence:, normalizers:, **normalizer_options)
              @state.update!(:normalizers)        { normalizers }        # immutable
              @state.update!(:normalizer_options) { normalizer_options } # immutable

              recompile!(sequence)
            end

            def merge!(activity)
              old_seq = @state.to_h[:sequence]
              new_seq = activity.to_h[:sequence]

              seq = Linear.Merge(old_seq, new_seq, end_id: "End.success")

              # Update the DSL's sequence, then recompile the actual activity.
              @state.update_sequence! { |**| seq }

              recompile_activity!(seq)
            end

            # Mainly used for introspection.
            def to_h
              activity = @state.get(:activity)

              activity.to_h.to_h.merge(
                activity: activity,
                sequence: @state.get(:sequence),
              )
            end

            # @Runtime
            # Injects {:exec_context} so that {:instance_method}s work.
            def call(args, **circuit_options)
              activity = @state.get(:activity)

              activity.(
                args,
                **circuit_options.merge(exec_context: new)
              )
            end

            def invoke(*args)
              TaskWrap.invoke(self, *args)
            end
          end # class << self
          # FIXME: do we want class << self?!

          module DSL
            module_function

            def start_sequence(wirings: [])
              start_default = Activity::Start.new(semantic: :default)
              start_event   = Linear::Sequence.create_row(task: start_default, id: "Start.default", magnetic_to: nil, wirings: wirings)
              _sequence     = Linear::Sequence[start_event]
            end
          end # DSL

          # FIXME: move to State#dup
          def self.copy(value, **) # DISCUSS: should that be here?
            value.copy
          end

          state = Declarative::State(
            # sequencer: [nil, copy: method(:copy)], # when inherited, call sequencer.copy
            normalizers: [nil, {}],        # immutable
            normalizer_options: [nil, {}], # immutable

            sequence:  [nil, {}], # when inherited, call #dup
            activity:  [nil, {}], # when inherited, call #dup

            fields:    [Hash.new, {}],
          )

          initialize!(state) # build an empty State instance that can be copied and recompiled.
          # override :sequencer, :sequence, :activity
          # This is done in every subclass.
          recompile!(DSL.start_sequence)
        end # Strategy
      end
    end
  end
end
