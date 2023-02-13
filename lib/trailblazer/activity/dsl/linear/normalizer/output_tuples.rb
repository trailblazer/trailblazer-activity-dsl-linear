module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements
          module OutputTuples
            # Logic related to {Output() => ...}, called "Wiring API".
            # TODO: move to different namespace (feature/dsl)
            def self.Output(semantic, is_generic: true)
              Normalizer::OutputTuples::Output::Semantic.new(semantic, is_generic)
            end

            module Output
              # Note that both {Semantic} and {CustomOutput} are {kind_of?(Output)}
              Semantic      = Struct.new(:semantic, :generic?).include(Output)
              CustomOutput  = Struct.new(:signal, :semantic, :generic?).include(Output) # generic? is always false
            end


            # 1. remember custom tuples (Output and output_semantic)
            # 2. convert Output, and add to :outputs
            # 3. now OutputSemantic only to be treated

            def self.normalize_output_tuples(ctx, non_symbol_options:, **)
              output_tuples = non_symbol_options.find_all { |k,v| k.is_a?(OutputTuples::Output) }

              ctx.merge!(output_tuples: output_tuples)
            end

            # Remember all custom (non-generic) {:output_tuples}.
            def self.remember_custom_output_tuples(ctx, output_tuples:, non_symbol_options:, **)
              # We don't include generic OutputSemantic (from Subprocess(strict: true)) for inheritance, as this is not a user customization.
              custom_output_tuples = output_tuples.reject { |k,v| k.generic? }

              # save Output() tuples under {:custom_output_tuples} for inheritance.
              ctx.merge!(
                non_symbol_options: non_symbol_options.merge(
                  Normalizer::Inherit.Record(custom_output_tuples.to_h, type: :custom_output_tuples)
                )
              )
            end

            # Take all Output(signal, semantic), convert to OutputSemantic and extend {:outputs}.
            # Since only users use this style, we don't have to filter.
            def self.register_additional_outputs(ctx, output_tuples:, outputs:, **)
              # We need to preserve the order when replacing Output with OutputSemantic,
              # that's why we recreate {output_tuples} here.
              output_tuples =
                output_tuples.collect do |(output, connector)|
                  if output.kind_of?(Output::CustomOutput)
                    # add custom output to :outputs.
                    outputs = outputs.merge(output.semantic => Activity.Output(output.signal, output.semantic))

                    # Convert Output to OutputSemantic.
                    [Strategy.Output(output.semantic), connector]
                  else
                    [output, connector]
                  end
                end

              ctx.merge!(
                output_tuples: output_tuples,
                outputs:            outputs
              )
            end

            # 1. :outputs is provided by DSL
# 2. IF :inherit => copy inherited Output tuples
# 3. convert Output (without semantic, btw, change that) and add to :outputs
# 4. IF :inherit and strict == false (in step-options,not Subprocess) => throw out Output with unknown semantic

            # Implements {inherit: :outputs, strict: false}
            # return connections from {parent} step which are supported by current step
            def self.filter_inherited_output_tuples(ctx, inherit: false, inherited_recorded_options: {}, outputs:, output_tuples:, **)
              return unless inherit === true
              strict_outputs = false # TODO: implement "strict outputs" for inherit! meaning we connect all inherited Output regardless of the new activity's interface
              return if strict_outputs === true

              # Grab the inherited {:custom_output_tuples} so we can throw those out if the new activity doesn't support
              # the respective outputs.
              inherited_output_tuples_record  = inherited_recorded_options[:custom_output_tuples]
              inherited_output_tuples         = inherited_output_tuples_record ? inherited_output_tuples_record.options : {}

              allowed_semantics     = outputs.keys # these outputs are exposed by the inheriting step.
              inherited_semantics   = inherited_output_tuples.collect { |output, _| output.semantic }
              unsupported_semantics = inherited_semantics - allowed_semantics

              filtered_output_tuples = output_tuples.reject do |output, _| unsupported_semantics.include?(output.semantic) end

              ctx.merge!(
                output_tuples: filtered_output_tuples.to_h
              )
            end

            # we want this in the end:
            # {output.semantic => search strategy}
            def convert____connections

            end
          end # OutputTuples
        end
      end
    end
  end
end
