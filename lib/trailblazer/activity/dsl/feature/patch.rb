module Trailblazer
  class Activity
    module DSL
      module Feature # DISCUSS: this is Topology-specific and should probably reside there?
        module Patch
          def self.call(activity, path, block, patched_activity: Class.new(activity))
            task_id, *path = path

            patch =
              if task_id
                # segment_activity = Introspect.Nodes(activity, id: task_id).task
                task_wrap_circuit_for_segment = activity.to_h[:circuit].to_h[:nodes][task_id].task # FIXME: use Introspect API.
                segment_activity = task_wrap_circuit_for_segment.to_h[:nodes][:"task_wrap.call_task"].task # FIXME: use Introspect API.

                patched_segment_activity = call(segment_activity, path, block)

                # Replace the patched subprocess.
                -> { step Subprocess(patched_segment_activity), inherit: true, replace: task_id, id: task_id }
              else
                block # apply the *actual* patch from the Subprocess() call.
              end

            patched_activity.class_exec(&patch)
            patched_activity
          end

          # module DSL
          #   def patch(*path, &block)
          #     Patch.call(self, path, block, patched_activity: self)
          #   end
          # end
        end # Patch
      end
    end
  end
end
