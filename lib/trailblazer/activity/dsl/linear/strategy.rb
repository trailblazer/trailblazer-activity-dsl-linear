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

          # Called from {#step} and friends.
          def self.task_for!(state, type, task, options={}, &block)
            options = options.merge(dsl_track: type)

            # {#update_sequence} is the only way to mutate the state instance.
            state.update_sequence do |sequence:, normalizers:, normalizer_options:, fields:|
              # Compute the sequence rows.
              options = normalizers.(type, normalizer_options: normalizer_options, options: task, user_options: options.merge(sequence: sequence))

              sequence = Activity::DSL::Linear::DSL.apply_adds_from_dsl(sequence, **options)
            end
          end

          # @public
          private def step(*args, &block)
            recompile_activity_for(:step, *args, &block)
          end

          private def recompile_activity_for(type, *args, &block)
            args = forward_block(args, block)

            seq  = @state.send(type, *args)

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

          private def forward_block(args, block)
            options = args[1]

            return args unless options.is_a?(Hash)

              # FIXME: doesn't account {task: <>} and repeats logic from Normalizer.

            # DISCUSS: THIS SHOULD BE DONE IN DSL.Path() which is stateful! the block forwarding should be the only thing happening here!
            evaluated_options =
            options.find_all { |k,v| v.is_a?(BlockProxy) }.collect do |output, proxy|
              shared_options = {step_interface_builder: @state.instance_variable_get(:@normalizer_options)[:step_interface_builder]} # FIXME: how do we know what to pass on and what not?

              [output, Linear.Path(**shared_options, **proxy.options, &(proxy.block || block))] # FIXME: the || sucks.
            end

            evaluated_options = Hash[evaluated_options]

            return args[0], options.merge(evaluated_options)
          end

          def Path(**options, &block) # syntactically, we can't access the {do ... end} block here.
            BlockProxy.new(options, block)
          end

          BlockProxy = Struct.new(:options, :block)

          private def merge!(activity)
            old_seq = @state.instance_variable_get(:@sequence) # TODO: fixme
            new_seq = activity.instance_variable_get(:@state).instance_variable_get(:@sequence) # TODO: fix the interfaces

            seq = Linear.Merge(old_seq, new_seq, end_id: "End.success")

            @state.instance_variable_set(:@sequence, seq) # FIXME: hate this so much.
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
