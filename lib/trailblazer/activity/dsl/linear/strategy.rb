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
              sequence = apply_on_sequence(type, *args, &block)

              recompile!(sequence)
            end

            # @return Sequence
            private def apply_on_sequence(type, arg, options = {}, &block)
              ctx = DSL.invoke_normalizer(
                type,
                arg,
                options,
                sequence:           @state.get(:sequence),
                normalizers:        @state.get(:normalizers),
                normalizer_options: @state.get(:normalizer_options),
                &block
              )

              return ctx[:sequence]
            rescue Activity::Adds::IndexError # TODO: allow passing the "source class" to compiling.
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
            def compile_strategy!(strategy_dsl, *args, **kws)
              sequence = initialize_options!(strategy_dsl, *args, **kws) # sets @sequence.

              recompile!(sequence)
            end

            # This is logic done only once, when creating a new Strategy base type.
            # DISCUSS: i think the {options_from_strategy} arg is never passed anywhere, by design!
            #
            def initialize_options!(strategy_class, user_options_for_strategy = {}, options_from_strategy = strategy_class.options_for_initialize(**user_options_for_strategy),
                normalizers:          options_from_strategy.fetch(:normalizers),
                normalizer_options:   options_from_strategy.fetch(:normalizer_options),
                layout_instructions:  options_from_strategy.fetch(:layout_instructions)
              )

              @state.update!(:normalizers) { normalizers }
              @state.update!(:normalizer_options) { normalizer_options }
              @state.update!(:sequence) { Activity.Pipeline({}) }

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
            def call(ctx, flow_options, circuit_options = {}) # DISCUSS: do we want to require {flow_options} here?
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

            def options_for_initialize(**options) # DISCUSS: only needed for a very specific test.
              options
            end


            # Build is a mix of inheritance and composition. We want DSL methods from the superclass, but also need to allow injecting alternative normalizers etc.
            # In case those aren't passed, we "inherit" normalizers and normalizer_options from the superclass, too.
            # This isn't hacky at all, just a bit tricky since Ruby doesn't allow passing options into the {#inherited} method.
            #
            # Also it would probably be better to have three options methods, default_normalizers, default_normalizer_options and default_layout, currently we have
            # one big method per strategy that computes unnecessary things, such as the layout_instructions or the normalizer even if it was passed here.
            def Build(strategy, normalizers: strategy.instance_variable_get(:@state).get(:normalizers), layout_instructions: nil, **normalizer_options_from_user, &block)
              options = {normalizers: normalizers}
              options.merge!(layout_instructions: layout_instructions) if layout_instructions

              Class.new(strategy) do
                compile_strategy!(strategy::DSL, normalizer_options_from_user, **options) # sets @sequence.
                # pp @state.get(:normalizers)

                class_exec(&block) if block
              end
            end

            # Call a specific normalizer for an invocation of step, left, fail, terminus, pass.
            # @private
            # DISCUSS: used in {Normalizer#add_terminus}, too.
            def self.invoke_normalizer(type, task, options, normalizers:, normalizer_options:, sequence:, &block)
              # These options represent direct configuration of the very method call that causes the normalizer to be run.
              options = {
                dsl_track:   type,
                block:       block,
                normalizers: normalizers,
                sequence:    sequence,
              }.merge(options)

                # **options,
              options = options.merge(
                **normalizer_options,
                normalizer_options: normalizer_options, # currently, we need those as an "extra" option in Helper::Path. # FIXME: test these options.
              )

              ctx = normalizers.(
                type,
                {
                  options:            task,               # macro-options
                  user_options:       options,            # user-specified options from the DSL method
                }
              )
            end

          end # DSL

          # FIXME: move to State#dup
          def self.copy(value, **) # DISCUSS: should that be here?
            value.copy
          end

          require_relative "feature/merge"
          extend Merge::DSL # {Strategy.merge!}

          def self.normalizer_ext_for_initial_task_wrap(ctx, *, **)
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
          # DISCUSS: currently, a Strategy is an abstract class that cannot be used directly unless you configure it using Build(). See strategy_test.
          # compile_strategy!(self, {}, normalizers: {}, normalizer_options: {}, layout_instructions: [])
        end # Strategy
      end
    end
  end
end
