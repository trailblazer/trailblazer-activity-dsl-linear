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
              extensions_ary =
                non_symbol_options
                  .find_all { |k, v| k.instance_of?(Extensions::Extension) }
                  .to_h
                  .values

              ctx.merge!(
                task_wrap_extensions: task_wrap_extensions + extensions_ary
              )
            end

            def compile_task_wrap_from_extensions(ctx, task_wrap_extensions:, task_wrap: [], **) # TODO: test {:task_wrap}, should we allow it to get injected?
              task_wrap = task_wrap_extensions.inject(task_wrap) { |task_wrap, ext| ext.(task_wrap) }

              task_wrap = Activity::TaskWrap::Pipeline.new(task_wrap)

              ctx.merge!(task_wrap: task_wrap)
            end
          end
        end
      end
    end
  end
end
