module Trailblazer
  class Activity
    module DSL
      module Linear
        module Normalizer
          # Implements {:extensions} option and allows adding taskWrap extensions using
          # Linear::Normalizer::Extensions.Extension().

          # 0. normalizer extensions are grabbed from :normalizer_extensions
          # 1. normalizer extensions are evaluated, they add DSL objects at "normalizer time"
          # 2. those DSL objects are transformed through the normalizer, e.g. In()
          # 3. task_wrap_extensions are evaluated
          def self.Extension(ext) # Normalizer::Extension # TODO: leave here or move?
            ext # we could wrap it, but currently it's not necessary. This is for forward-compatibility.
          end

          # Implements the concept of "normalizer extensions".
          # DISCUSS: Generic "left" Extension() handling is done where?.
          module Extensions
            # Left side of DSL.
            Extension = Struct.new(:generic?, :id, :append)

            module_function

            # DSL object, the left side of the hash.
            def Extension(is_generic: false, id: rand, append: nil)
              Extension.new(is_generic, id, append) # {id} has to be unique for every Extension instance (for Hash identity).
            end

            # Don't record Extension()s created by the DSL! This happens in VariableMapping, for instance.
            # Either the user also inherits I/O tuples and the extension will be recreated,
            # or they really don't want this particular extension to be inherited.
            def compile_recorded_extensions(ctx, flow_options, _, **)
              recorded_extension_tuples =
                ctx
                  .find_all { |k, v| k.instance_of?(Extension) }
                  .reject   { |k, v| k.generic? }
                  .to_h

              ctx = ctx.merge(
                Normalizer::Inherit.Record(recorded_extension_tuples, type: :extensions)
              )

              return ctx, flow_options
            end

            # Fetch the {:normalizer_extensions} from the activity's field.
            def compute_normalizer_extensions(ctx, flow_options, _, subprocess: false, task:, normalizer_extensions: nil, **)
              return ctx, flow_options if normalizer_extensions

              if subprocess
                # Activity subclasses maintain a field {:task_wrap_extensions} that can be used to expose the
            #   # taskWrap for the activity itself to an outer user, e.g. when being nested.
                normalizer_extensions = task.to_h[:fields].fetch(:normalizer_extensions)
              else
                normalizer_extensions = Strategy::INITIAL_NORMALIZER_EXTENSIONS
              end

              ctx = ctx.merge(normalizer_extensions: normalizer_extensions)

              return ctx, flow_options
            end

            # (Normalizer step)
            # Compile all normalizer extensions.
            # Note that they have access to the entire normalizer {ctx}.
            def compile_normalizer_extensions(ctx, flow_options, circuit_options, normalizer_extensions:, **)
              # pp normalizer_extensions
              normalizer_extensions.each do |ext| # FIXME: this is basically a Pipeline.
                ctx, flow_options = circuit_options[:runner].(ext, ctx, flow_options, circuit_options)
              end

              return ctx, flow_options
            end
          end # Extensions
        end
      end
    end
  end
end
