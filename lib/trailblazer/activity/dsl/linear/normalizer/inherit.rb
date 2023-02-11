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
            Record = Struct.new(:options, :type, :non_symbol_options?) # FIXME: i hate symbol vs. non-symbol.

            def Record(options, type:, from_non_symbol_options: true)
              Record.new(options, type, from_non_symbol_options)
            end

            # Currently, the {:inherit} option copies over {:extensions} from the original step and merges them with new :extensions.
            #
          ### Recall
            # Fetch remembered options and add them to the processed options.
            def recall_recorded_options(ctx, non_symbol_options:, sequence:, inherit: nil, id:, extensions:[],**)
              return unless inherit === true || inherit.is_a?(Array)

              # E.g. {variable_mapping: true, wiring_api: true}
              types_to_recall =
                if inherit === true
                  # we want to inherit "everything": extensions, output_tuples, variable_mapping
                  Hash.new {true}
                else
                  inherit.collect { |type| [type, true] }.to_h
                end

              row = find_row(sequence, id) # from this row we're inheriting options.

              # DISCUSS: should we maybe revert the idea of separating options by type?
              # Anyway, key idea here is that Record() users don't have to know these details
              # about symbol vs. non-symbol.
              symbol_options_to_merge     = {}
              non_symbol_options_to_merge = {}

              row.data[:recorded_options].each do |type, record|
                next unless types_to_recall[type]
                # raise record.inspect
                target = record.non_symbol_options? ? non_symbol_options_to_merge : symbol_options_to_merge

                target.merge!(record.options)
              end

              ctx[:non_symbol_options] = non_symbol_options_to_merge.merge(non_symbol_options)
              # ctx = symbol_options_to_merge.merge(ctx)  #FIXME: implement
              ctx.merge!(
                inherited_recorded_options: row.data[:recorded_options]
              )




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
            end

            def find_row(sequence, id)
              index = Activity::Adds::Insert.find_index(sequence, id)
              sequence[index]
            end

          ### Record
            # Figure out what to remember from the options and store it in {row.data[:recorded_options]}.
            # Note that this is generic logic not tied to variable_mapping, OutputTuples or anything.
            def compile_recorded_options(ctx, non_symbol_options:, **)
              recorded_options = {}

              non_symbol_options
                .find_all { |k,v| k.instance_of?(Record) }
                .collect  do |k,v|
                  recorded_options[k.type] = k   # DISCUSS: we overwrite potential data with same type.
                end

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
