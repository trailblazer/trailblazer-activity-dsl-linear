class Trailblazer::Activity
  module DSL
    module Linear
      def self.Patch(activity, instructions)
        Patch.customize(activity, options: instructions)
      end

      module Patch
      # DISCUSS: we could make this a generic DSL option, not just for Subprocess().
        # Currently, this is called from the Subprocess() helper.
        def self.customize(activity, options:)
          options = options.is_a?(Proc) ?
            { [] => options } : # hash-wrapping with empty path, for patching given activity itself
            options

          options.each do |path, patch|
            activity = call(activity, path, patch) # TODO: test if multiple patches works!
          end

          activity
        end

        def self.call(activity, path, customization)
          task_id, *path = path

          patch =
            if task_id
              segment_activity = Introspect::TaskMap(activity).find_by_id(task_id).task
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
    end
  end
end
