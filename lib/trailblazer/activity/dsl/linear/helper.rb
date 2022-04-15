module Trailblazer
  class Activity
    module DSL
      module Linear
        # Data Structures used in the DSL. They're mostly created from helpers
        # and then get processed in the normalizer.
        #
        # @private
        OutputSemantic = Struct.new(:value)
        Id             = Struct.new(:value)
        Track          = Struct.new(:color, :adds, :options)
        Extension      = Struct.new(:callable) do
          def call(*args, &block)
            callable.(*args, &block)
          end
        end
        PathBranch       = Struct.new(:options)
        DataVariableName = Class.new

        # Shortcut functions for the DSL.
        # Those are included in {Strategy} so they're available to all Strategy users such
        # as {Railway} or {Operation}.
        module Helper
          #   Output( Left, :failure )
          #   Output( :failure ) #=> Output::Semantic
          def Output(signal, semantic=nil)
            return OutputSemantic.new(signal) if semantic.nil?

            Activity.Output(signal, semantic)
          end

          def End(semantic)
            Activity.End(semantic)
          end

          def end_id(semantic:, **)
            "End.#{semantic}" # TODO: use everywhere
          end

          def Track(color, wrap_around: false)
            Track.new(color, [], wrap_around: wrap_around).freeze
          end

          def Id(id)
            Id.new(id).freeze
          end

          def Path(**kws, &block)
            @state.Path(**kws, &block)
          end

          # Computes the {:outputs} options for {activity}.
          def Subprocess(activity, patch: {})
            activity = Patch.customize(activity, options: patch)

            {
              task:    activity,
              outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
            }
          end

          def In(**kws);     VariableMapping::DSL::In(**kws); end
          def Out(**kws);    VariableMapping::DSL::Out(**kws); end
          def Inject(**kws); VariableMapping::DSL::Inject(**kws); end

          def DataVariable
            DataVariableName.new
          end

          module Patch
            module_function

            def customize(activity, options:)
              options = options.is_a?(Proc) ?
                { [] => options } : # hash-wrapping with empty path, for patching given activity itself
                options

              options.each do |path, patch|
                activity = call(activity, path, patch) # TODO: test if multiple patches works!
              end

              activity
            end

            def call(activity, path, customization)
              task_id, *path = path

              patch =
                if task_id
                  segment_activity = Introspect::Graph(activity).find(task_id).task
                  patched_segment_activity = call(segment_activity, path, customization)

                  # Replace the patched subprocess.
                  -> { step Subprocess(patched_segment_activity), inherit: true, replace: task_id, id: task_id }
                else
                  customization # apply the *actual* patch from the Subprocess() call.
                end

              patched_activity = Class.new(activity)
              patched_activity.class_exec(&patch)
              patched_activity
            end
          end # Patch
        end # Helper
      end # Linear
    end # DSL
  end # Activity
end
