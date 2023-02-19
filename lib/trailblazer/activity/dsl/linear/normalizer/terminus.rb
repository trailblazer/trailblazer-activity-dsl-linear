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
                "activity.normalize_step_interface"       => Normalizer.Task(Normalizer.method(:normalize_step_interface)),      # first
                "activity.merge_library_options"          => Normalizer.Task(Normalizer.method(:merge_library_options)),    # Merge "macro"/user options over library options.
                "activity.normalize_for_macro"            => Normalizer.Task(Normalizer.method(:merge_user_options)),
                "activity.normalize_normalizer_options"   => Normalizer.Task(Normalizer.method(:merge_normalizer_options)),
                "activity.normalize_non_symbol_options"   => Normalizer.Task(Normalizer.method(:normalize_non_symbol_options)),
                "activity.normalize_context"              => Normalizer.method(:normalize_context),
                "terminus.normalize_task"                 => Normalizer.Task(Terminus.method(:normalize_task)),
                "terminus.normalize_id"                   => Normalizer.Task(method(:normalize_id)),
                "terminus.normalize_magnetic_to"          => Normalizer.Task(Terminus.method(:normalize_magnetic_to)),
                "terminus.append_end"                     => Normalizer.Task(Terminus.method(:append_end)),

                "activity.compile_data" => Normalizer.Task(Normalizer.method(:compile_data)), # FIXME
                "activity.create_row" => Normalizer.Task(Normalizer.method(:create_row)),
                "activity.create_add" => Normalizer.Task(Normalizer.method(:create_add)),
                "activity.create_adds" => Normalizer.Task(Normalizer.method(:create_adds)),
                }

              TaskWrap::Pipeline.new(normalizer_steps.to_a)
            end

            # @private
            def normalize_id(ctx, id: nil, semantic:, **)
              ctx.merge!(
                id: id || Strategy.end_id(semantic: semantic)
              )
            end

            # @private
            # Set {:task} and {:semantic}.
            def normalize_task(ctx, task:, **)
              if task.kind_of?(Activity::End) # DISCUSS: do we want this check?
                ctx = _normalize_task_for_end_event(ctx, **ctx)
              else
                # When used such as {terminus :found}, create the end event automatically.
                ctx = _normalize_task_for_symbol(ctx, **ctx)
              end
            end

            def _normalize_task_for_end_event(ctx, task:, **) # you cannot override using {:semantic}
              ctx.merge!(
                semantic: task.to_h[:semantic]
              )
            end

            def _normalize_task_for_symbol(ctx, task:, semantic: task, **)
              ctx.merge!(
                task:     Activity.End(semantic),
                semantic: semantic,
              )
            end

            # @private
            def normalize_magnetic_to(ctx, magnetic_to: nil, semantic:, **)
              return if magnetic_to
              ctx.merge!(magnetic_to: semantic)
            end

            # @private
            def append_end(ctx, task:, semantic:, append_to: "End.success", **)
              terminus_args = {
                sequence_insert: [Activity::Adds::Insert.method(:Append), append_to],
                stop_event:      true
              }

              ctx.merge!(
                wirings: [
                  Linear::Sequence::Search::Noop(
                    Activity::Output.new(task, semantic), # DISCUSS: do we really want to transport the semantic "in" the object?
                  )
                ],
                adds: [],
                **terminus_args
              )
            end
          end # Terminus
        end
      end
    end
  end
end
