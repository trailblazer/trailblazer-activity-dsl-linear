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
              sequence = apply_step_on_sequence_builder(type, *args, &block)

              recompile!(sequence)
            end

            # TODO: make {rescue} optional, only in dev mode.
            # @return Sequence
            private def apply_step_on_sequence_builder(type, arg, options={}, &block)
              return Sequence::Builder.(type, arg, options,
                sequence:           @state.get(:sequence),
                normalizers:        @state.get(:normalizers),

                normalizer_options: @state.get(:normalizer_options),

                 &block
              )

            rescue Activity::Adds::IndexError
              # re-raise this exception with activity class prepended
              # to the message this time.
              raise $!, "#{self}:#{$!.message}"
            end

            private def recompile_activity(sequence)
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
              options = DSL.OptionsForSequenceBuilder(strategy_dsl, **options)

              compile_strategy_for!(**options)
            end

            def compile_strategy_for!(sequence:, normalizers:, **normalizer_options)
              @state.update!(:normalizers)        { normalizers }        # immutable
              @state.update!(:normalizer_options) { normalizer_options } # immutable

              recompile!(sequence)
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

            def invoke(*args, **kws)
              TaskWrap.invoke(self, *args, **kws)
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

            def Build(strategy, **options, &block)
              Class.new(strategy) do
                compile_strategy!(strategy::DSL, normalizers: @state.get(:normalizers), **options)

                class_exec(&block) if block_given?
              end
            end

            def OptionsForSequenceBuilder(strategy_dsl, termini: nil, **user_options)
              # DISCUSS: instead of calling a separate {initial_sequence} method we could make DSL strategies
              # use the actual DSL to build up the initial_sequence, somewhere outside? Maybe using {:adds}?
              strategy_options, strategy_termini = strategy_dsl.options_for_sequence_build(**user_options) # call Path.options_for_sequence_builder

              # DISCUSS: passing on Normalizers here is a service, not sure I like it.
              initial_sequence = process_termini(strategy_options[:sequence], termini || strategy_termini, normalizers: strategy_dsl::Normalizers)

              {
                step_interface_builder: method(:build_circuit_task_for_step),
                adds:                   [], # DISCUSS: needed?
                **user_options,
                **strategy_options, # this might (and should!) override :track_name etc.
                sequence:               initial_sequence,
              }
              # no {:termini} left in options
            end

            # If no {:termini} were provided by the Strategy user, we use the default
            # {strategy_termini}.
            def process_termini(sequence, termini, **options_for_append_terminus)
              termini.each do |task, terminus_options|
                sequence = append_terminus(sequence, task, **options_for_append_terminus, **terminus_options)
              end

              return sequence
            end

            def append_terminus(sequence, task, normalizers:, **options)
              # DISCUSS: why are we requiring {:normalizers} here? only for invoking Normalizer.terminus
              _sequence = Linear::Sequence::Builder.update_sequence_for(:terminus, task, options, normalizers: normalizers, sequence: sequence, normalizer_options: {})
            end

            # Wraps {user_step} into a circuit-interface compatible callable, a.k.a. "task".
            def build_circuit_task_for_step(user_step)
              Activity::Circuit::TaskAdapter.for_step(user_step, option: true)
            end
          end # DSL


          # FIXME: move to State#dup
          def self.copy(value, **) # DISCUSS: should that be here?
            value.copy
          end

          require_relative "feature/merge"
          extend Merge::DSL # {Strategy.merge!}

          state = Declarative::State(
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


