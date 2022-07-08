module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(**options)
          extension, normalizer_options, non_symbol_options = VariableMapping.merge_instructions_from_dsl(**options)

          return TaskWrap::Extension::WrapStatic.new(extension: extension), normalizer_options, non_symbol_options
        end

        module VariableMapping
          # Add our normalizer steps to the strategy's normalizer.
          def self.extend!(strategy, *step_methods) # DISCUSS: should this be implemented in Linear?
            Linear::Normalizer.extend!(strategy, *step_methods) do |normalizer|
              Linear::Normalizer.prepend_to(
                normalizer,
                "activity.wirings",
                {
                   # In(), Out(), {:input}, Inject() feature
                  "activity.normalize_input_output_filters" => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:normalize_input_output_filters)),
                  "activity.input_output_dsl"               => Linear::Normalizer.Task(VariableMapping::Normalizer.method(:input_output_dsl)),
                }
              )
            end
          end

          # Steps that are added to the DSL normalizer.
          module Normalizer
            # Process {In() => [:model], Inject() => [:current_user], Out() => [:model]}
            def self.normalize_input_output_filters(ctx, non_symbol_options:, **)
              input_exts  = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::In) }
              output_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Out) }
              inject_exts = non_symbol_options.find_all { |k,v| k.is_a?(VariableMapping::DSL::Inject) }

              return unless input_exts.any? || output_exts.any? || inject_exts.any?

              ctx[:inject_filters] = inject_exts
              ctx[:in_filters]     = input_exts
              ctx[:out_filters]    = output_exts
            end

            def self.input_output_dsl(ctx, extensions: [], **options)
              # no :input/:output/:inject/Input()/Output() passed.
              return if (options.keys & [:input, :output, :inject, :inject_filters, :in_filters, :output_filters]).empty?

              extension, normalizer_options, non_symbol_options = Linear.VariableMapping(**options)

              ctx[:extensions] = extensions + [extension] # FIXME: allow {Extension() => extension}
              ctx.merge!(**normalizer_options) # DISCUSS: is there another way of merging variables into ctx?
              ctx[:non_symbol_options].merge!(non_symbol_options)
            end
          end

          module_function

          # For the input filter we
          #   1. create a separate {Pipeline} instance {pipe}. Depending on the user's options, this might have up to four steps.
          #   2. The {pipe} is run in a lamdba {input}, the lambda returns the pipe's ctx[:input_ctx].
          #   3. The {input} filter in turn is wrapped into an {Activity::TaskWrap::Input} object via {#merge_instructions_for}.
          #   4. The {TaskWrap::Input} instance is then finally placed into the taskWrap as {"task_wrap.input"}.
          #
          # @private
          #

            # default_input
          #  <or>
            # oldway
            #   :input
            #   :inject
            # newway(initial_input_pipeline)
            #   In,Inject
          # => input_pipe
          def merge_instructions_from_dsl(**options)
            # The overriding {:input} option is set.
            pipeline, has_mono_options, _ = DSL.pipe_for_mono_input(**options)

            if ! has_mono_options
              pipeline = DSL.pipe_for_composable_input(**options)  # FIXME: rename filters consistently
            end

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input  = Pipe::Input.new(pipeline)


            output_pipeline, has_mono_options, _ = DSL.pipe_for_mono_output(**options)

            if ! has_mono_options
              output_pipeline = DSL.pipe_for_composable_output(**options)
            end

            output = Pipe::Output.new(output_pipeline)

            return TaskWrap::VariableMapping.Extension(input, output, id: input.object_id), # wraps filters: {Input(input), Output(output)}
              # normalizer_options:
              {
                variable_mapping_pipelines: [pipeline, output_pipeline],
              },
              # non_symbol_options:
              {
                Linear::Strategy.DataVariable() => :variable_mapping_pipelines # we want to store {:variable_mapping_pipelines} in {Row.data} for later reference.
              }
              # DISCUSS: should we remember the pure pipelines or get it from the compiled extension?
              # store pipe in the extension (via TW::Extension.data)?
          end



# < AddVariables
#   Option
#     filter
#   MergeVariables

          # Runtime classes
          Filter = Struct.new(:aggregate_step, :filter, :name, :add_variables_class)

          # These objects are created via the DSL, keep all i/o steps in a Pipeline
          # and run the latter when being `call`ed.
          module Pipe
            class Input
              def initialize(pipe)
                @pipe = pipe
              end

              def call((ctx, flow_options), **circuit_options) # This method is called by {TaskWrap::Input#call} in the {activity} gem.
                wrap_ctx, _ = @pipe.({original_ctx: ctx}, [[ctx, flow_options], circuit_options])

                wrap_ctx[:input_ctx]
              end
            end

            # API in VariableMapping::Output:
            #   output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)
            # Returns {output_ctx} that is used after taskWrap finished.
            class Output < Input
              def call(returned_ctx, (original_ctx, returned_flow_options), **original_circuit_options)
                wrap_ctx, _ = @pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx}, [[original_ctx, returned_flow_options], original_circuit_options])

                wrap_ctx[:aggregate]
              end
            end
          end

# DISCUSS: improvable sections such as merge vs hash[]=
          def initial_aggregate(wrap_ctx, original_args)
            wrap_ctx = wrap_ctx.merge(aggregate: {})

            return wrap_ctx, original_args
          end

          # Merge all original ctx variables into the new input_ctx.
          # This happens when no {:input} is provided.
          def default_input_ctx(wrap_ctx, original_args)
            default_ctx = wrap_ctx[:original_ctx]

            MergeVariables(default_ctx, wrap_ctx, original_args)
          end

          # Input/output Pipeline step that runs the user's {filter} and adds
          # variables to the computed ctx.
          #
          # Basically implements {:input}.
          #
# AddVariables: I call something with an Option-interface and run the return value through MergeVariables().
          # works on {:aggregate} by (usually) producing a hash fragment that is merged with the existing {:aggregate}
          class AddVariables
            def initialize(filter, user_filter)
              @filter      = filter # The users input/output filter.
              @user_filter = user_filter # this is for introspection.
            end

            def call(wrap_ctx, original_args)
              ((original_ctx, _), circuit_options) = original_args
              # puts "@@@@@ #{wrap_ctx[:returned_ctx].inspect}"

              # this is the actual logic.
              variables = call_filter(wrap_ctx, original_ctx, circuit_options, original_args)

              VariableMapping.MergeVariables(variables, wrap_ctx, original_args)
            end

            def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
              _variables = @filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options)
            end

            class ReadFromAggregate < AddVariables # FIXME: REFACTOR
              def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                new_ctx = wrap_ctx[:aggregate]

                _variables = @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end
            end

            class Output < AddVariables
              def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                new_ctx = wrap_ctx[:returned_ctx]

                @filter.(new_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
              end

              # Pass {inner_ctx, outer_ctx, **inner_ctx}
              class WithOuterContext < Output
                def call_filter(wrap_ctx, original_ctx, circuit_options, original_args)
                  new_ctx = wrap_ctx[:returned_ctx]

                  @filter.(new_ctx, original_ctx, keyword_arguments: new_ctx.to_hash, **circuit_options)
                end
              end

              # Always deletes from {:aggregate}.
              class Delete < AddVariables
                def call(wrap_ctx, original_args)
                  @filter.collect do |name|
                    wrap_ctx[:aggregate].delete(name) # FIXME: we're mutating a hash here!
                  end

                  return wrap_ctx, original_args
                end
              end
            end
          end

          # Finally, create a new input ctx from all the
          # collected input variables.
          # This goes into the step/nested OP.
          def scope(wrap_ctx, original_args)
            ((_, flow_options), _) = original_args

            # this is the actual context passed into the step.
            wrap_ctx[:input_ctx] = Trailblazer::Context(
              wrap_ctx[:aggregate],
              {}, # mutable variables
              flow_options[:context_options]
            )

            return wrap_ctx, original_args
          end

          # Last call in every step. Currently replaces {:input_ctx} by adding variables using {#merge}.
          # DISCUSS: improve here?
          def MergeVariables(variables, wrap_ctx, original_args)
            wrap_ctx[:aggregate] = wrap_ctx[:aggregate].merge(variables)

            return wrap_ctx, original_args
          end

          # @private
          # The default {:output} filter only returns the "mutable" part of the inner ctx.
          # This means only variables added using {inner_ctx[..]=} are merged on the outside.
          def default_output_ctx(wrap_ctx, original_args)
            new_ctx = wrap_ctx[:returned_ctx]

            _wrapped, mutable = new_ctx.decompose # `_wrapped` is what the `:input` filter returned, `mutable` is what the task wrote to `scoped`.

            MergeVariables(mutable, wrap_ctx, original_args)
          end

          def merge_with_original(wrap_ctx, original_args)
            original_ctx     = wrap_ctx[:original_ctx]  # outer ctx
            output_variables = wrap_ctx[:aggregate]

            wrap_ctx[:aggregate] = original_ctx.merge(output_variables) # FIXME: use MergeVariables()
            # pp wrap_ctx
            return wrap_ctx, original_args
          end
        end # VariableMapping
      end
    end
  end
end
