module Trailblazer
  class Activity
    module DSL
      module Feature
        module Extension
          module TaskWrap
            # DISCUSS: add other tW related logic here from Normalizer::Step?
            # This logic needs {:adds_for_task_wrap} to be present, and to be an array.
            # This option, however, is the concept of this very extension, so we can't default
            # :adds_for_task_wrap in the canonical normalizer.
            module Normalizer
              # Add third-party steps to the {:task_wrap_pipeline} for the currently
              # compiled step.
              def self.apply_adds_to_task_wrap_pipeline(ctx, flow_options, _, task_wrap_pipeline:, adds_for_task_wrap:, **)
                task_wrap_pipeline = Circuit::Adds.(task_wrap_pipeline, *adds_for_task_wrap)

                return ctx.merge(task_wrap_pipeline: task_wrap_pipeline), flow_options
              end

              # def sort_task_wrap_extensions(task_wrap_extension_tuples)
              #   # FIXME: make this faster and less clumsy, I suck at algorithms!
              #   to_sort = task_wrap_extension_tuples.find_all { |left_ext, _| left_ext.append }
              #   sorted_task_wrap_extension_tuples = task_wrap_extension_tuples - to_sort

              #   exts_pipeline = sorted_task_wrap_extension_tuples.collect { |left_ext, ext| [left_ext.id, ext] }

              #   to_sort_adds = to_sort.collect { |left_ext, ext| [ext, id: left_ext.id, append: left_ext.append] }

              #   exts_pipeline = Activity::Adds.(exts_pipeline, *to_sort_adds) # FIXME: this doesn't cover all cases of sorting

              #   exts_pipeline.collect { |row| row[1] }
              # end

              Node = Circuit::Node[method(:apply_adds_to_task_wrap_pipeline), Circuit::Task::Adapter::LibInterface]
            end
          end # TaskWrap
        end
      end
    end
  end
end
