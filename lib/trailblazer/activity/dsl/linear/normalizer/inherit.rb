module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements the generic {:inherit} option.
          # Features such as variable mapping or the Wiring API can
          # use the generic behavior for their inheritance.
          module Inherit
            module_function

            # Options you want to have stored and inherited can be
            # declared using Record.
            Record = Struct.new(:option_names, :type)

            def Record(*option_names, type:)
              Record.new(option_names, type)
            end

            # Currently, the {:inherit} option copies over {:extensions} from the original step and merges them with new :extensions.
            #
            def inherit_option(ctx, inherit: false, sequence:, id:, extensions: [], non_symbol_options:, **)
              return unless inherit === true

              row = find_row(sequence, id) # from this row we're inheriting options.

              # FIXME: "inherit.extensions"
              inherited_extensions  = row.data[:extensions]

              ctx[:extensions]  = Array(inherited_extensions) + Array(extensions)


              # FIXME: this should be part of the :inherit pipeline, but "inherit.fast_track_options"
              inherited_fast_track_options =
                [:pass_fast, :fail_fast, :fast_track].collect do |option|
                  row.data.key?(option) ? [option, row.data[option]] : nil
                end.compact.to_h

              inherited_fast_track_options.each do |k,v| # FIXME: we should provide this generically for all kinds of options.
                ctx[k] = v
              end



              # FIXME: this should be part of the :inherit pipeline, but "inherit.output_tuples"
              inherited_output_tuples  = row.data[:custom_output_tuples] || {} # Output() tuples from superclass. (2.)

              ctx[:non_symbol_options] = inherited_output_tuples.merge(non_symbol_options)
              ctx[:inherited_output_tuples] = inherited_output_tuples
            end

            def find_row(sequence, id)
              index = Activity::Adds::Insert.find_index(sequence, id)
              sequence[index]
            end

          ### remember
            # Figure out what to remember in {row.data[:recorded_options]}.
            # Note that this is generic logic not tied to variable_mapping, OutputTuples or anything.
            def compile_recorded_options(ctx, non_symbol_options:, **)
              recorded_options = {}

              non_symbol_options
                .find_all { |k,v| k.instance_of?(Record) }
                .collect  { |k,v| recorded_options[k.type] = ctx.slice(*k.option_names) }  # DISCUSS: we overwrite potential data with same type.

              ctx.merge!(
                recorded_options:   recorded_options,
                # add {row.data[:recorded_options]} in Sequence:
                non_symbol_options: non_symbol_options.merge(Strategy.DataVariable() => :recorded_options)
              )
            end
          end # Inherit
        end
      end
    end
  end
end
