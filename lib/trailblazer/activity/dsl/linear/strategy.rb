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
        module Strategy
          def initialize!(state)
            @state    = state

            recompile_activity!(@state.to_h[:sequence])
          end

          def inherited(inheriter)
            super

            # inherits the {@sequence}, and options.
            inheriter.initialize!(@state.copy)
          end

        # FIXME: move me to {DSL::task_for!}!
          # Called from {#step} and friends.
          def self.task_for!(state, type, task, options={}, &block)
            options = options.merge(dsl_track: type)

            # {#update_sequence} is the only way to mutate the state instance.
            state.update_sequence do |sequence:, normalizers:, normalizer_options:, **|
              # Compute the sequence rows.
              options = normalizers.(type, normalizer_options: normalizer_options, options: task, user_options: options.merge(sequence: sequence))

              sequence = Activity::DSL::Linear::DSL.apply_adds_from_dsl(sequence, **options)
            end
          end

          # @public
          def step(*args, &block)
            # Recompiling the activity/sequence is a matter specific to Strategy (Railway etc).
            recompile_activity_for(:step, *args, &block)
          end

          private def recompile_activity_for(type, *args, &block)
            seq  = @state.send(type, *args, &block)

            recompile_activity!(seq)
          rescue Sequence::IndexError
            # re-raise this exception with activity class prepended
            # to the message this time.
            raise $!, "#{self}:#{$!.message}"
          end

          private def recompile_activity!(seq)
            schema    = Compiler.(seq)

            @activity = Activity.new(schema)
          end

          private def merge!(activity)
            old_seq = @state.to_h[:sequence]
            new_seq = activity.instance_variable_get(:@state).to_h[:sequence] # TODO: fix the {@state} interface.

            seq = Linear.Merge(old_seq, new_seq, end_id: "End.success")

            # Update the DSL's sequence, then recompile the actual activity.
            @state.update_sequence { |**| seq }
            recompile_activity!(seq)
          end

          def to_h
            @activity.to_h.to_h.merge(activity: @activity)
          end

          # Injects {:exec_context} so that {:instance_method}s work.
          def call(args, **circuit_options)
            @activity.(
              args,
              **circuit_options.merge(exec_context: new)
            )
          end

          def invoke(*args)
            TaskWrap.invoke(self, *args)
          end
        end # Strategy
      end
    end
  end
end
