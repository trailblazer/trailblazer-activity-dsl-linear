module Trailblazer
  class Activity
    module DSL
      module Linear
        module VariableMapping
          # Implements the {inherit: [:variable_mapping]} feature.
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
              # Inheriting the original I/O happens by grabbing the variable_mapping_pipelines
              # from the original sequence and pass it on in the normalizer.
              # It will eventually get processed by {VariableMapping#pipe_for_composable_input} etc.
              def self.inherit_option(ctx, inherit: [], sequence:, id:, non_symbol_options:, **)
                # return unless inherit.is_a?(Array)
                if inherit  == true
                  # here, :extensions will be copied by the superordinate :inherit mechanism.
                  # This is, strictly speaking, not correct as it's not doing what we do here.
                  return
                elsif inherit.is_a?(Array)
                return unless inherit.include?(:variable_mapping)
              else return end

                inherited_in_filters  = Linear::Normalizer::Inherit.find_row(sequence, id).data[:in_filters]
                inherited_out_filters = Linear::Normalizer::Inherit.find_row(sequence, id).data[:out_filters]

                inherited_filters = inherited_in_filters.to_h.merge(inherited_out_filters.to_h)

                ctx[:non_symbol_options] = inherited_filters.merge(non_symbol_options) # inherited must be *before* new options!
              end
            end
          end
        end # VariableMapping
      end
    end
  end
end
