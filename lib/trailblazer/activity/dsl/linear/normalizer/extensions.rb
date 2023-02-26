module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements {:extensions} option and allows adding taskWrap extensions using
          # Linear::Normalizer::Extensions.Extension().
          module Extensions
            module_function

            Extension = Struct.new(:generic?, :id)

            def Extension(is_generic: false)
              Extension.new(is_generic, rand) # {id} has to be unique for every Extension instance (for Hash identity).
            end

            # Convert {:extensions} option to {Extension} tuples. The new way of adding extensions is
            #   step ..., Extension() => my_extension
            def convert_extensions_option_to_tuples(ctx, non_symbol_options:, extensions: nil, **)
              return unless extensions
              # TODO: deprecate {:extensions} in the DSL?

              extensions_tuples = extensions.collect { |ext| [Extension(), ext] }.to_h

              ctx.merge!(
                non_symbol_options: non_symbol_options.merge(extensions_tuples)
              )
            end

            def compile_extensions(ctx, non_symbol_options:, **)
              extensions_ary =
                non_symbol_options
                  .find_all { |k, v| k.instance_of?(Extension) }
                  .to_h
                  .values

              ctx.merge!(
                extensions: extensions_ary
              )
            end

            # Don't record Extension()s created by the DSL! This happens in VariableMapping, for instance.
            # Either the user also inherits I/O tuples and the extension will be recreated,
            # or they really don't want this particular extension to be inherited.
            def compile_recorded_extensions(ctx, non_symbol_options:, **)
              recorded_extension_tuples =
                non_symbol_options
                  .find_all { |k, v| k.instance_of?(Extension) }
                  .reject   { |k, v| k.generic? }
                  .to_h

              ctx.merge!(
                non_symbol_options: non_symbol_options.merge(
                  Normalizer::Inherit.Record(recorded_extension_tuples, type: :extensions)
                )
              )
            end
          end # Extensions
        end
      end
    end
  end
end
