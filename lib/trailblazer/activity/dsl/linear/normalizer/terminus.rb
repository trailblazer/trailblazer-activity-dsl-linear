module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Normalizer pipeline for the {terminus} DSL method.
          module Terminus
            module_function

            def Normalizer
              normalizer_steps =
                {
                  "activity.normalize_step_interface"       => Normalizer.method(:normalize_step_interface),      # first
                  "activity.merge_library_options"          => Normalizer.method(:merge_library_options),    # Merge "macro"/user options over library options.
                  "activity.normalize_for_macro"            => Normalizer.method(:merge_user_options),
                  "activity.normalize_normalizer_options"   => Normalizer.method(:merge_normalizer_options),
                  # "activity.normalize_non_symbol_options"   => Normalizer.Task(Normalizer.method(:normalize_non_symbol_options)),
                  "activity.normalize_context"              => Normalizer.method(:normalize_context),

                  "terminus.normalize_task"                 => Terminus.method(:normalize_task),
                  "terminus.normalize_id"                   => method(:normalize_id),
                  "terminus.normalize_magnetic_to"          => Terminus.method(:normalize_magnetic_to),
                  "terminus.append_end"                     => Terminus.method(:append_end),

                  "activity.sequence_insert"                => Normalizer.method(:normalize_sequence_insert),

                  # "step.normalize_task_wrap_extensions" => Normalizer.Task(TaskWrap.method(:normalize_task_wrap_extensions)),
                  "step.compute_normalizer_extensions" => Normalizer::Extensions.method(:compute_normalizer_extensions),
                  "step.compile_normalizer_extensions" => Normalizer::Extensions.method(:compile_normalizer_extensions),
                  "step.add_dsl_extensions_to_task_wrap_extensions" => TaskWrap.method(:add_dsl_extensions_to_task_wrap_extensions),
                  "step.compile_task_wrap_from_extensions" => TaskWrap.method(:compile_task_wrap_from_extensions),

                  "activity.compile_data" => Normalizer.method(:compile_data), # FIXME: redundant with {Linear::Normalizer}.
                  "activity.create_row" => Normalizer.method(:create_row),
                  "activity.create_add" => Normalizer.method(:create_add),
                  "activity.create_adds" => Normalizer.method(:create_adds),
                  "activity.apply_adds" => Normalizer.method(:apply_adds),
                }

              Activity::Pipeline(normalizer_steps)
            end

            # @private
            def normalize_id(ctx, flow_options, _, semantic:, id: Strategy.end_id(semantic: semantic), **)
              ctx = ctx.merge(
                id: id
              )

              return ctx, flow_options
            end

            # @private
            # Set {:task} and {:semantic}.
            def normalize_task(ctx, flow_options, _, task:, **)
              if task.is_a?(Activity::End) # DISCUSS: do we want this check?
                ctx = _normalize_task_for_end_event(ctx, **ctx)
              else
                # When used such as {terminus :found}, create the end event automatically.
                ctx = _normalize_task_for_symbol(ctx, **ctx)
              end

              return ctx, flow_options
            end

            def _normalize_task_for_end_event(ctx, task:, **) # you cannot override using {:semantic}
              ctx.merge(
                semantic: task.to_h[:semantic]
              )
            end

            def _normalize_task_for_symbol(ctx, task:, semantic: task, **)
              ctx.merge(
                task:     Activity.End(semantic),
                semantic: semantic
              )
            end

            # @private
            def normalize_magnetic_to(ctx, flow_options, _, magnetic_to: nil, semantic:, **)
              return ctx, flow_options if magnetic_to

              ctx = ctx.merge(magnetic_to: semantic)

              return ctx, flow_options
            end

            # @private
            def append_end(ctx, flow_options, _, task:, append_to: "End.success", **)
              terminus_args = {
                sequence_insert:    {append: append_to}, #[Activity::Adds::Insert.method(:Append), append_to],
                stop_event:         true,
                Strategy.DataVariable() => [:stop_event, :semantic],
              }

              ctx = ctx.merge(
                wirings: [],
                adds:    [],
              ).merge(terminus_args)
                # **terminus_args
              return ctx, flow_options
            end
          end # Terminus
        end
      end
    end
  end
end
