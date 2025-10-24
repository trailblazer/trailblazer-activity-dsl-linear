module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements the generic {:inherit} option.
          # Features such as variable mapping or the Wiring API can
          # use the generic behavior for their inheritance.

          # "generic": built by the DSL from options, options that are inherited, so you might not want to record or inherit generic options
          module Inherit
            module_function

            # Options you want to have stored and inherited can be
            # declared using Record.
            Record = Struct.new(:options, :type)

            def Record(options, type:)
              {Record.new(options, type) => nil}
            end

            # Currently, the {:inherit} option copies over {:extensions} from the original step and merges them with new :extensions.
            #
            ### Recall
            # Fetch remembered options and add them to the processed options.
            def recall_recorded_options(ctx, flow_options, _, sequence:, id:, inherit: nil, **)
              return ctx, flow_options unless inherit === true || inherit.is_a?(Array)

              # E.g. {variable_mapping: true, wiring_api: true}
              types_to_recall =
                if inherit === true
                  # we want to inherit "everything": extensions, output_tuples, variable_mapping
                  Hash.new { true }
                else
                  inherit.collect { |type| [type, true] }.to_h
                end

              row = find_row(sequence, id) # from this row we're inheriting options.

              # recorded_options: for example [:fast_track, :custom_output_tuples, :extensions]
              row.data[:recorded_options].each do |type, record|
                next unless types_to_recall[type]

                ctx = record.options.merge(ctx)
              end


              ctx = ctx.merge(
                inherited_recorded_options: row.data[:recorded_options]
              )

              return ctx, flow_options
            end

            def find_row(sequence, id)
              Activity::Pipeline.find(sequence, id: id)
            end

            ### Record
            # Figure out what to remember from the options and store it in {row.data[:recorded_options]}.
            # Note that this is generic logic not tied to variable_mapping, OutputTuples or anything.
            def compile_recorded_options(ctx, flow_options, _, **)
              recorded_options = {}

              ctx
                .find_all { |k, v| k.instance_of?(Record) }
                .collect  do |k, v|
                  recorded_options[k.type] = k   # DISCUSS: we overwrite potential data with same type.
                end

              ctx = ctx.merge(
                recorded_options:   recorded_options,
                # add {row.data[:recorded_options]} in Sequence:
                Strategy.DataVariable() => :recorded_options
              )

              return ctx, flow_options
            end
          end # Inherit
        end
      end
    end
  end
end
