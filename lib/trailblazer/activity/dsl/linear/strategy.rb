require "forwardable"

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
            state.update_sequence do |sequence:, normalizers:, normalizer_options:|
              # Compute the sequence rows.
              options = normalizers.(type, normalizer_options: normalizer_options, options: task, user_options: options.merge(sequence: sequence))

              sequence = Activity::DSL::Linear::DSL.apply_adds_from_dsl(sequence, options)
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
          end

          private def recompile_activity!(seq)
            schema    = Compiler.(seq)

            @activity = Activity.new(schema)
          end

          private def forward_block(args, block)
            options = args[1]
            if options.is_a?(Hash) # FIXME: doesn't account {task: <>} and repeats logic from Normalizer.
              output, proxy = (options.find { |k,v| v.is_a?(BlockProxy) } or return args)
              shared_options = {step_interface_builder: @state.instance_variable_get(:@normalizer_options)[:step_interface_builder]} # FIXME: how do we know what to pass on and what not?
              return args[0], options.merge(output => Linear.Path(**shared_options, **proxy.options, &block))
            end

            args
          end

          extend Forwardable
          def_delegators Linear, :Output, :End, :Track, :Id, :Subprocess

          def Path(options) # we can't access {block} here, syntactically.
            BlockProxy.new(options)
          end

          BlockProxy = Struct.new(:options)

          private def merge!(activity)
            old_seq = @state.instance_variable_get(:@sequence) # TODO: fixme
            new_seq = activity.instance_variable_get(:@state).instance_variable_get(:@sequence) # TODO: fix the interfaces

            seq = Linear.Merge(old_seq, new_seq, end_id: "End.success")

            @state.instance_variable_set(:@sequence, seq) # FIXME: hate this so much.
          end

          extend Forwardable
          def_delegators :@activity, :to_h

          # Injects {:exec_context} so that {:instance_method}s work.
          def call(args, circuit_options={})
            @activity.(
              args,
              circuit_options.merge(exec_context: new)
            )
          end
        end # Strategy
      end
    end
  end
end
