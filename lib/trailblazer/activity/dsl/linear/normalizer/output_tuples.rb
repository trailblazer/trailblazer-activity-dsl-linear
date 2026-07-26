module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements Output(:success) => Track(:success)
          # Internals are documented: https://trailblazer.to/2.1/docs/internals.html#internals-wiring-api-output-tuples
          module OutputTuples
            module_function





            # Connector representing a (to-be-created?) terminus when using End(:semantic).
            class End < Struct.new(:semantic)
              def call(ctx)
                sequence = ctx[:sequence]

                end_id     = Linear::Strategy.end_id(semantic: semantic)
                end_exists = Activity::Pipeline.find(sequence, id: end_id) # FIXME: the to_a happening internally here has been done before, this is wrong.

                terminus = Activity.End(semantic)

                adds = end_exists ? [] : OutputTuples::Connections.adds_for_terminus(terminus, semantic: semantic, id: end_id, sequence: sequence, normalizers: ctx[:normalizers], normalizer_options: ctx[:normalizer_options])

                return Sequence::Search::ById.new(end_id), adds
              end
            end



            module Output

            end



            # Remember all custom (non-generic) {:output_tuples}.
            def remember_custom_output_tuples(ctx, flow_options, _, output_tuples:, **)
              # We don't include generic OutputSemantic (from Subprocess(strict: true)) for inheritance, as this is not a user customization.
              custom_output_tuples = output_tuples.reject { |k, v| k.generic? }

              # save Output() tuples under {:custom_output_tuples} for inheritance.
              ctx = ctx.merge(
                Normalizer::Inherit.Record(custom_output_tuples.to_h, type: :custom_output_tuples)
              )

              return ctx, flow_options
            end

            # Implements {inherit: :outputs, strict: false}
            # return connections from {parent} step which are supported by current step
            def filter_inherited_output_tuples(ctx, flow_options, _, outputs:, output_tuples:, inherit: false, inherited_recorded_options: {}, **)
              return ctx, flow_options unless inherit === true
              strict_outputs = false # TODO: implement "strict outputs" for inherit! meaning we connect all inherited Output regardless of the new activity's interface
              return ctx, flow_options if strict_outputs === true

              # Grab the inherited {:custom_output_tuples} so we can throw those out if the new activity doesn't support
              # the respective outputs.
              inherited_output_tuples_record  = inherited_recorded_options[:custom_output_tuples]
              inherited_output_tuples         = inherited_output_tuples_record ? inherited_output_tuples_record.options : {}

              allowed_semantics     = outputs.keys # these outputs are exposed by the inheriting step.
              inherited_semantics   = inherited_output_tuples.collect { |output, _| output.semantic }
              unsupported_semantics = inherited_semantics - allowed_semantics

              filtered_output_tuples = output_tuples.reject { |output, _| unsupported_semantics.include?(output.semantic) }

              ctx = ctx.merge(
                output_tuples: filtered_output_tuples.to_h
              )

              return ctx, flow_options
            end

            # Compile connections from tuples.
            module Connections
              module_function



              # Returns ADDS for the new terminus.
              # @private
              def adds_for_terminus(terminus, **options)
                ctx = Strategy::DSL.invoke_normalizer(:terminus, terminus, options, normalizers: options[:normalizers], normalizer_options: options[:normalizer_options], sequence: [])

                ctx[:adds]
              end
            end # Connections
          end # OutputTuples
        end
      end
    end
  end
end
