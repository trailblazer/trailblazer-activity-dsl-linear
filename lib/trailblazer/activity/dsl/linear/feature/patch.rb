class Trailblazer::Activity
  module DSL
    module Linear
      module Patch
        # Currently, this is called from the Subprocess() helper.
        def self.customize(activity, options:)
          options = options.is_a?(Proc) ?
            {[] => options} : # hash-wrapping with empty path, for patching given activity itself
            options

          options.each do |path, patch|
            activity = call(activity, path, patch) # TODO: test if multiple patches works!
          end

          activity
        end

        def self.call(activity, path, customization, patched_activity: Class.new(activity))
          task_id, *path = path

          patch =
            if task_id
              segment_activity = Introspect.Nodes(activity, id: task_id).task
              patched_segment_activity = call(segment_activity, path, customization)

              # Replace the patched subprocess.
              -> { step Subprocess(patched_segment_activity), inherit: true, replace: task_id, id: task_id }
            else
              customization # apply the *actual* patch from the Subprocess() call.
            end

          patched_activity.class_exec(&patch)
          patched_activity
        end

        module DSL
          def patch(*path, &block)
            Patch.call(self, path, block, patched_activity: self)
          end
        end
      end # Patch
    end
  end
end
