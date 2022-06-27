module Trailblazer
  class Activity
    module DSL
      module Linear
        module VariableMapping
          module Inherit
            def self.extended(strategy) # FIXME: who implements {extend!}
              Linear::Normalizer.extend!(strategy, :step) do |normalizer|
                Linear::Normalizer.prepend_to(
                  normalizer,
                  "activity.normalize_input_output_filters",
                  {
                    "variable_mapping.inherit_option" => Linear::Normalizer.Task(VariableMapping::Inherit::Normalizer.method(:inherit_option)),
                  }
                )
              end
            end

            module Normalizer
              def self.inherit_option(ctx, inherit: [], sequence:, id:, **)
                return unless inherit.include?(:variable_mapping)

                inherited_input_pipeline, inherited_output_pipeline = Linear::Normalizer::InheritOption.find_row(sequence, id).data[:variable_mapping_pipelines]

                # this eventually gets processed by {VariableMapping#pipe_for_composable_input}.
                ctx[:initial_input_pipeline] = inherited_input_pipeline
              end
            end
          end
        end #VariableMapping
      end
    end
  end
end
