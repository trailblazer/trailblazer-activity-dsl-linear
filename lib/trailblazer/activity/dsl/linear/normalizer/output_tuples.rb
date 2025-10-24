module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements Output(:success) => Track(:success)
          # Internals are documented: https://trailblazer.to/2.1/docs/internals.html#internals-wiring-api-output-tuples
          module OutputTuples
            module_function

            # Connector when using Id(:validate).
            class Id < Struct.new(:value)
              def to_a(*)
                return [Linear::Sequence::Search.method(:ById), value], [] # {value} is the "target".
              end
            end

            # Connector when using Track(:success).
            class Track < Struct.new(:color, :adds, :options)
              def to_a(*)
                search_strategy = options[:wrap_around] ? :WrapAround : :Forward

                return [Linear::Sequence::Search.method(search_strategy), color], adds
              end
            end

            # Connector representing a (to-be-created?) terminus when using End(:semantic).
            class End < Struct.new(:semantic)
              def to_a(ctx)
                sequence = ctx[:sequence]

                end_id     = Linear::Strategy.end_id(semantic: semantic)
                end_exists = Activity::Pipeline.find(sequence, id: end_id) # FIXME: the to_a happening internally here has been done before, this is wrong.

                terminus = Activity.End(semantic)

                adds = end_exists ? [] : OutputTuples::Connections.add_terminus(terminus, id: end_id, sequence: sequence, normalizers: ctx[:normalizers])

                return [Linear::Sequence::Search.method(:ById), end_id], adds
              end
            end

            # Logic related to {Output() => ...}, called "Wiring API".
            # TODO: move to different namespace (feature/dsl)
            def Output(semantic, is_generic: true)
              Normalizer::OutputTuples::Output::Semantic.new(semantic, is_generic)
            end

            module Output
              # Note that both {Semantic} and {CustomOutput} are {is_a?(Output)}
              Semantic      = Struct.new(:semantic, :generic?).include(Output)
              CustomOutput  = Struct.new(:signal, :semantic, :generic?).include(Output) # generic? is always false
            end

            def normalize_output_tuples(ctx, flow_options, _, **)
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

            # Take all Output(signal, semantic), convert to OutputSemantic and extend {:outputs}.
            # Since only users use this style, we don't have to filter.
            def register_additional_outputs(ctx, flow_options, _, output_tuples:, outputs:, id:,**)
              # We need to preserve the order when replacing Output with OutputSemantic,
              # that's why we recreate {output_tuples} here.
              output_tuples =
                output_tuples.collect do |(output, connector)|
                  if output.is_a?(Output::CustomOutput)
                    # add custom output to :outputs.
                    outputs = outputs.merge(output.semantic => Activity.Output(output.signal, output.semantic))

                    # Convert Output to OutputSemantic.
                    [Strategy.Output(output.semantic), connector]
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

              # we want this in the end:
              # {output.semantic => search strategy}
              def compile_wirings(ctx, flow_options, _, adds:, output_tuples:, outputs:, id:, **)
                # DISCUSS: how could we add another magnetic_to to an end?
                # Go through all {Output() => Track()/Id()/End()} tuples.
                wirings =
                  output_tuples.collect do |output, target|
                    (search_builder, search_args), connector_adds = target.to_a(ctx) # Call {#to_a} on Track/Id/End/...

                    adds += connector_adds

                    semantic = output.semantic
                    output   = outputs[semantic] || raise("No `#{semantic}` output found for #{id.inspect} and outputs #{outputs.inspect}")

                    # return proc to be called when compiling Seq, e.g. {ById(output, :id)}
                    search_builder.(output, *search_args)
                  end

                ctx = ctx.merge(
                  wirings: wirings,
                  adds: adds
                )

                return ctx, flow_options
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
