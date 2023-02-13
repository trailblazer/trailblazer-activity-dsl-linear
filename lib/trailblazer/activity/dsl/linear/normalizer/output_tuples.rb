module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements
          module OutputTuples
            module_function

            # Logic related to {Output() => ...}, called "Wiring API".
            # TODO: move to different namespace (feature/dsl)
            def Output(semantic, is_generic: true)
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

            def normalize_output_tuples(ctx, non_symbol_options:, **)
              output_tuples = non_symbol_options.find_all { |k,v| k.is_a?(OutputTuples::Output) }

              ctx.merge!(output_tuples: output_tuples)
            end

            # Remember all custom (non-generic) {:output_tuples}.
            def remember_custom_output_tuples(ctx, output_tuples:, non_symbol_options:, **)
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
            def register_additional_outputs(ctx, output_tuples:, outputs:, **)
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
                outputs:       outputs
              )
            end

            # 1. :outputs is provided by DSL
# 2. IF :inherit => copy inherited Output tuples
# 3. convert Output (without semantic, btw, change that) and add to :outputs
# 4. IF :inherit and strict == false (in step-options,not Subprocess) => throw out Output with unknown semantic

            # Implements {inherit: :outputs, strict: false}
            # return connections from {parent} step which are supported by current step
            def filter_inherited_output_tuples(ctx, inherit: false, inherited_recorded_options: {}, outputs:, output_tuples:, **)
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

            # Compile connections from tuples.
            module Connections
              module_function

              # we want this in the end:
              # {output.semantic => search strategy}
              # Process {Output(:semantic) => target} and make them {:connections}.
              def compile_connections(ctx, adds:, output_tuples:, sequence:, normalizers:, **)
                # Find all {Output() => Track()/Id()/End()}
                return unless output_tuples.any?

                connections = {}

                # DISCUSS: how could we add another magnetic_to to an end?
                output_tuples.each do |output, cfg|
                  new_connections, add =
                    if cfg.is_a?(Linear::Track)
                      [output_to_track(ctx, output, cfg), cfg.adds] # FIXME: why does Track have a {adds} field? we don't use it anywhere.
                    elsif cfg.is_a?(Linear::Id)
                      [output_to_id(ctx, output, cfg.value), []]
                    elsif cfg.is_a?(Activity::End)
                      end_id     = Activity::Railway.end_id(**cfg.to_h)
                      end_exists = Activity::Adds::Insert.find_index(ctx[:sequence], end_id)

                      _adds = end_exists ? [] : add_terminus(cfg, id: end_id, sequence: sequence, normalizers: normalizers)

                      [output_to_id(ctx, output, end_id), _adds]
                    else
                      raise cfg.inspect
                    end

                  connections = connections.merge(new_connections)
                  adds += add
                end

                ctx[:connections] = connections
                ctx[:adds]        = adds
              end

              # @private
              def output_to_track(ctx, output, track)
                search_strategy = track.options[:wrap_around] ? :WrapAround : :Forward

                {output.semantic => [Linear::Sequence::Search.method(search_strategy), track.color]}
              end

              # @private
              def output_to_id(ctx, output, target)
                {output.semantic => [Linear::Sequence::Search.method(:ById), target]}
              end

              # Returns ADDS for the new terminus.
              # @private
              def add_terminus(end_event, id:, sequence:, normalizers:)
                step_options = Linear::Sequence::Builder.invoke_normalizer_for(:terminus, end_event, {id: id}, sequence: sequence, normalizer_options: {}, normalizers: normalizers)

                step_options[:adds]
              end
            end # Connections
          end # OutputTuples
        end
      end
    end
  end
end
