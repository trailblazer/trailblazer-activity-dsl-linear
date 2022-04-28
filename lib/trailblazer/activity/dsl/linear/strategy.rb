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

              # recompile_activity!(@state.to_h[:sequence])
            end

            def inherited(inheriter)
              super

              # inherits the {@sequence}, and options.
              inheriter.initialize!(@state.copy) # FIXME: technically you don't have to recompute anything here, everything can be copied and @activity set.
            end

            # @public
              # We forward `step` to the Dsl (State) object.
              # Recompiling the activity/sequence is a matter specific to Strategy (Railway etc).
            def step(*args, &block); recompile_activity_for(:step, *args, &block); end
            def terminus(*args);     recompile_activity_for(:terminus, *args); end

            private def recompile_activity_for(type, *args, &block)
              sequencer, sequence = apply_step_on_state!(type, *args, &block)

              recompile!(sequencer, sequence) # FIXME: update sequence and @activity
            end

            # TODO: make {rescue} optional, only in dev mode.
            private def apply_step_on_state!(type, *args, &block)
              # Simply call {@state.step} with all the beautiful args.
              sequencer = @state.get(:sequencer)

              sequence  = sequencer.send(type, *args, &block) # sequencer gets mutated.

              return sequencer, sequence
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
            def recompile!(sequencer, sequence)
              activity = recompile_activity(sequence)

              @state.update!(:sequencer) { |*| sequencer }
              @state.update!(:sequence) { |*| sequence }
              @state.update!(:activity) { |*| activity }
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

          # TODO: rename to recompile_for_strategy! or something.
          # DISCUSS: only used in Path and friends.
          def self.recompile_for_state!(state_class, options_for_state)
            sequencer, sequence = state_class.build(**options_for_state)
            # return sequencer, sequence
            recompile!(sequencer, sequence)
          end

          # FIXME: move to State#dup
          def self.copy(value, **) # DISCUSS: should that be here?
            value.copy
          end

          sequencer, sequence = Linear::State.build(normalizers: {}, initial_sequence: DSL.start_sequence)
          activity = recompile_activity(sequence) # sets @activity. this is only for faster access in #call.

          state = Declarative::State(
            sequencer: [sequencer, copy: method(:copy)], # when inherited, call sequencer.copy
            sequence:  [sequence, {}], # when inherited, call #dup # DISCUSS: do we want to keep this here?
            activity:  [activity, {}], # when inherited, call #dup
            fields:    [Hash.new, {}],
          )

          initialize!(state) # build an empty State instance that can be copied and recompiled.
        end # Strategy
      end
    end
  end
end
