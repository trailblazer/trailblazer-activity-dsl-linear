module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Normalizer steps specific to compiling each step's taskWrap.
          # NOTE: we could make this a separate extension.
          module TaskWrap # TODO: rename to Extension, or move there.
            module_function

            # (Normalizer step)
            def add_dsl_extensions_to_task_wrap_extensions(ctx, flow_options, _, task_wrap_extensions: [], **) # FIXME: do we want the {:task_wrap_extensions} kwarg? # FIXME: test task_wrap_extensions
              task_wrap_extension_tuples = ctx.find_all { |k, v| k.instance_of?(Extensions::Extension) }

              extensions_ary = sort_task_wrap_extensions(task_wrap_extension_tuples)

              ctx = ctx.merge(
                task_wrap_extensions: task_wrap_extensions + extensions_ary
              )

              return ctx, flow_options
            end

            # (Normalizer step)
            def compile_task_wrap_from_extensions(ctx, flow_options, _, task_wrap_extensions:, task_wrap: Activity::Pipeline({}), **) # TODO: test {:task_wrap}, should we allow it to get injected?
              task_wrap = task_wrap_extensions.inject(task_wrap) { |task_wrap, ext| ext.(task_wrap) }

              ctx = ctx.merge(task_wrap: task_wrap)

              return ctx, flow_options
            end

            # @private
            # TODO: benchmark that in context of {Invoke.call} with a common OP with, say, 10 steps.
            def sort_task_wrap_extensions(task_wrap_extension_tuples)
              # FIXME: make this faster and less clumsy, I suck at algorithms!
              to_sort = task_wrap_extension_tuples.find_all { |left_ext, _| left_ext.append }
              sorted_task_wrap_extension_tuples = task_wrap_extension_tuples - to_sort

              exts_pipeline = sorted_task_wrap_extension_tuples.collect { |left_ext, ext| [left_ext.id, ext] }

              to_sort_adds = to_sort.collect { |left_ext, ext| [ext, id: left_ext.id, append: left_ext.append] }

              exts_pipeline = Activity::Adds.(exts_pipeline, *to_sort_adds) # FIXME: this doesn't cover all cases of sorting

              exts_pipeline.collect { |row| row[1] }
            end
          end
        end
      end
    end
  end
end
