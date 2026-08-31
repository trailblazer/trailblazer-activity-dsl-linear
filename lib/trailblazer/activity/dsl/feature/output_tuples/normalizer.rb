module Trailblazer
  class Activity
    module DSL
      module Feature
        module OutputTuples
          # Extract all "output tuples", compile a {:wirings} hash.
          module Normalizer
            module_function

            def wirings_present?(ctx, flow_options, _, **)
              return ctx, flow_options, ctx.key?(:wirings) ? Right : Left
            end

            def normalize_output_tuples(ctx, flow_options, _, **kws)
              output_tuples = ctx.find_all { |k, v| k.is_a?(OutputTuples::Output) }

              # key by semantic in the order they were added to filter out overridden default outputs:
              #
              # E.g. [[:failure => A], [:success => :B], [:failure => C]] becomes
              #                       [[:success => :B], [:failure => C]]
              outputs_by_semantic = output_tuples.collect { |output, target| [output.semantic, [output, target]] }.to_h
              output_tuples = outputs_by_semantic.collect { |_, (output, target)| [output, target] }.to_h

              ctx = ctx.merge(output_tuples: output_tuples)

              return ctx, flow_options
            end

            # Take all Output(signal, semantic), convert to OutputSemantic and extend {:outputs}.
            # Since only users use this style, we don't have to filter.
            def register_additional_outputs(ctx, flow_options, _, output_tuples:, outputs:, id:,**)
              # We need to preserve the order when replacing Output with OutputSemantic,
              # that's why we recreate {output_tuples} here.
              output_tuples =
                output_tuples.collect do |(output, connector)|
                  if output.is_a?(Output::CustomSignal)
                    # add custom output to :outputs.
                    outputs = outputs.merge(output.semantic => Activity::Output.new(output.signal, output.semantic))

                    # Convert Output to Output::Semantic:
                    [Helper.Output(output.semantic), connector]
                  else
                    [output, connector]
                  end
                end

              ctx = ctx.merge(
                output_tuples: output_tuples,
                outputs:       outputs
              )

              return ctx, flow_options
            end

            # we want this in the end:
            # {output.semantic => search strategy}
            def compile_wirings(ctx, flow_options, _, adds_for_sequence: [], output_tuples:, outputs:, id:, **)
              # DISCUSS: how could we add another magnetic_to to an end?
              # Go through all {Output() => Track()/Id()/End()} tuples.
              wirings =
                output_tuples.collect do |output, target|
                  semantic = output.semantic
                  output   = outputs[semantic] || raise("No `#{semantic}` output found for #{id.inspect} and outputs #{outputs.inspect}")

                  search, connector_adds = target.(**ctx)

                  adds_for_sequence += connector_adds

                  [output, search]
                end
# pp wirings
              ctx = ctx.merge(
                wirings:           wirings.to_h,
                adds_for_sequence: adds_for_sequence
              )

              return ctx, flow_options
            end

            circuit = Trailblazer::Circuit::Builder.Circuit(
              [:wirings_present?, method(:wirings_present?),
                  connections: {Right => [nil, Right], Left => [:normalize_output_tuples, Left]}],
              [:normalize_output_tuples, method(:normalize_output_tuples)],
              [:register_additional_outputs, method(:register_additional_outputs)], # this is a feature in the feature and could be deactivated.
              [:compile_wirings, method(:compile_wirings)],
            )

            Node = Trailblazer::Circuit::Node[circuit, Circuit::Processor]
          end # Normalizer
        end
      end
    end
  end
end
