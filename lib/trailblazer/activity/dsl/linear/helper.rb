module Trailblazer
  class Activity
    module DSL
      module Linear
        module Helper
          # @api private
          OutputSemantic = Struct.new(:value)
          Id             = Struct.new(:value)
          Track          = Struct.new(:color, :adds, :options)
          Extension      = Struct.new(:callable) do
            def call(*args, &block)
              callable.(*args, &block)
            end
          end
          PathBranch     = Struct.new(:options)

          def self.included(base)
            base.extend ClassMethods
          end

          # Shortcut functions for the DSL.
          module ClassMethods
            #   Output( Left, :failure )
            #   Output( :failure ) #=> Output::Semantic
            def Output(signal, semantic=nil)
              return OutputSemantic.new(signal) if semantic.nil?

              Activity.Output(signal, semantic)
            end

            def End(semantic)
              Activity.End(semantic)
            end

            def end_id(_end)
              "End.#{_end.to_h[:semantic]}" # TODO: use everywhere
            end

            def Track(color, wrap_around: false)
              Track.new(color, [], wrap_around: wrap_around).freeze
            end

            def Id(id)
              Id.new(id).freeze
            end

            def Path(**options, &block)
              @state.Path(**options, &block)
            end

            # Connect last row of the {sequence} to the given step via its {Id}
            # Useful when steps needs to be inserted in between {Start} and {connect Id()}.
            private def connect_for_sequence(sequence, connect_to:)
              output, _ = sequence[-1][2][0].(sequence, sequence[-1]) # FIXME: the Forward() proc contains the row's Output, and the only current way to retrieve it is calling the search strategy. It should be Forward#to_h

              # searches = [Search.ById(output, connect_to.value)]
              searches = [Search.ById(output, connect_to.value)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Helper::Id)
              searches = [Search.Forward(output, connect_to.color)] if connect_to.instance_of?(Trailblazer::Activity::DSL::Linear::Helper::Track) # FIXME: use existing mapping logic!

              row = sequence[-1]
              row = row[0..1] + [searches] + [row[3]] # FIXME: not mutating an array is so hard: we only want to replace the "searches" element, index 2

              sequence = sequence[0..-2] + [row]

              sequence
            end

            # Computes the {:outputs} options for {activity}.
            def Subprocess(activity, patch: {})
              activity = Patch.customize(activity, options: patch)

              {
                task:    activity,
                outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
              }
            end

            def In(**options); VariableMapping::DSL::In(**options) end
            def Out(**options); VariableMapping::DSL::Out(**options) end
            def Inject(**options); VariableMapping::DSL::Inject(**options) end

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
            end

            def normalize(options, local_keys) # TODO: test me.
              locals  = options.reject { |key, value| ! local_keys.include?(key) }
              foreign = options.reject { |key, value| local_keys.include?(key) }
              return foreign, locals
            end
          end
        end # Helper

        include Helper # Introduce Helper constants in DSL::Linear scope
      end # Linear
    end # DSL
  end # Activity
end
