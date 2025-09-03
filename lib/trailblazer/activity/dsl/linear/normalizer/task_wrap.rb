module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Normalizer steps specific to compiling each step's taskWrap.
          # NOTE: we could make this a separate extension.
          module TaskWrap # TODO: rename to Extension, or move there.
            module_function

# FIXME: fetch_normalizer_extension
            # def compile_initial_task_wrap(ctx, task:, subprocess: false, **) # TODO: fetch_normalizer_extension.
            #   return unless subprocess

            #   # Activity subclasses maintain a field {:task_wrap_extensions} that can be used to expose the
            #   # taskWrap for the activity itself to an outer user, e.g. when being nested.
            #   extensions = task.to_h[:fields].fetch(:task_wrap_extensions)

            #   ctx[:initial_task_wrap_extensions] = extensions
            # end

            #
            # def normalize_task_wrap_extensions(ctx, task_wrap_extensions: nil, **)
            #   return if task_wrap_extensions

            #   # usually, non-Subprocess steps have no task_wrap_extensions set.
            #   ctx[:task_wrap_extensions] = Strategy::INITIAL_TASK_WRAP_EXTENSIONS # tw with one step: [<call_task>]
            # end

            # Normalizer step.
            def add_dsl_extensions_to_task_wrap_extensions(ctx, non_symbol_options:, task_wrap_extensions: [], **) # FIXME: do we want the {:task_wrap_extensions} kwarg?
              task_wrap_extension_tuples = non_symbol_options
                .find_all { |k, v| k.instance_of?(Extensions::Extension) }

              extensions_ary = sort_task_wrap_extensions(task_wrap_extension_tuples)

              ctx.merge!(
                task_wrap_extensions: task_wrap_extensions + extensions_ary
              )
            end

            def compile_task_wrap_from_extensions(ctx, task_wrap_extensions:, task_wrap: [], **) # TODO: test {:task_wrap}, should we allow it to get injected?
              task_wrap = task_wrap_extensions.inject(task_wrap) { |task_wrap, ext| ext.(task_wrap) }

              task_wrap = Activity::TaskWrap::Pipeline.new(task_wrap)

              ctx.merge!(task_wrap: task_wrap)
            end

            # @private
            def sort_task_wrap_extensions(task_wrap_extension_tuples)
              # FIXME: make this faster and less clumsy, I suck at algorithms!
              to_sort = task_wrap_extension_tuples.find_all { |left_ext, _| left_ext.append }
              sorted_task_wrap_extension_tuples = task_wrap_extension_tuples - to_sort

              exts_pipeline = sorted_task_wrap_extension_tuples.collect { |left_ext, ext| Activity::TaskWrap::Pipeline::Row(left_ext.id, ext) }

              exts_pipeline = to_sort.inject(exts_pipeline) do |pipe, (left_ext, ext)|
                Activity::Adds.(pipe, [ext, id: left_ext.id, append: left_ext.append]) # FIXME: this doesn't cover all cases of sorting
                # FIXME: we could throw in all adds instructions at once. very slow, though.
              end

              extensions_ary = exts_pipeline.collect { |row| row[1] }
            end
          end
        end
      end
    end
  end
end
