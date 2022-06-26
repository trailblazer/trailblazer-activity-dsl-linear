module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(output: nil, output_with_outer_ctx: false, input_filters: [], output_filters: [], injects: [], **options)
          if output && output_filters.any? # DISCUSS: where does this live?
            warn "[Trailblazer] You are mixing `:output` and `Out() => ...`. `Out()` options are ignored and `:output` wins."
            output_filters = []
          end

          extension, normalizer_options = VariableMapping.merge_instructions_from_dsl(output: output, output_with_outer_ctx: output_with_outer_ctx, input_filters: input_filters,
            output_filters: output_filters, injects: injects, **options)

          return TaskWrap::Extension::WrapStatic.new(extension: extension), normalizer_options
        end


# < AddVariables
#   Option
#     filter
#   MergeVariables
        module VariableMapping
          # Add our normalizer steps to the strategy's normalizer.
          def self.extended(strategy) # FIXME: who implements {extend!}
            Linear::Normalizer.extend!(strategy, :step) do |normalizer|
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

              ctx[:injects] = inject_exts
              ctx[:input_filters] = input_exts
              ctx[:output_filters] = output_exts # DISCUSS: naming
            end

            def self.input_output_dsl(ctx, extensions: [], input_filters: nil, output_filters: nil, injects: nil, **options)
              config = ctx.select { |k,v| [:input, :output, :output_with_outer_ctx, :inject].include?(k) } # TODO: optimize this, we don't have to go through the entire hash.
              config = config.merge(input_filters: input_filters)   if input_filters
              config = config.merge(output_filters: output_filters) if output_filters # TODO: hm, is this nice code?

              config = config.merge(injects: injects) if injects

              return unless config.any? # no :input/:output/:inject/Input()/Output() passed.

              extension, normalizer_options = Linear.VariableMapping(**config, **options)

              ctx[:extensions] = extensions + [extension] # FIXME: allow {Extension() => extension}
              ctx.merge!(**normalizer_options) # DISCUSS: is there another way of merging variables into ctx?
            end
          end

          module_function

          Filter = Struct.new(:aggregate_step, :filter, :name, :add_variables_class) # FIXME: move to DSL part

          # Adds the default_ctx step as per option {:add_default_ctx}
          def initial_input_pipeline(add_default_ctx: false)
            # No In() or {:input}. Use default ctx, which is the original ctxx.
            # When using Inject without In/:input, we also need a {default_input} ctx.
            default_ctx_row =
              add_default_ctx ? Activity::TaskWrap::Pipeline.Row(*default_input_ctx_config) : nil

            pipe = Activity::TaskWrap::Pipeline.new(
              [
                Activity::TaskWrap::Pipeline.Row("input.init_hash", VariableMapping.method(:initial_aggregate)), # very first step
                default_ctx_row,
                Activity::TaskWrap::Pipeline.Row("input.scope",     VariableMapping.method(:scope)), # last step
              ].compact
            )
          end

          def default_input_ctx_config # almost a Row.
            ["input.default_input", VariableMapping.method(:default_input_ctx)]
          end

          # Handle {:input} and {:inject} option, the "old" interface.
          def pipe_steps_for_input_option(pipeline, input:)
            tuple         = DSL.In(name: ":input") # simulate {In() => input}
            input_filter  = DSL::Tuple.filters_from_tuples([[tuple, input]])

            add_filter_steps(pipeline, input_filter)
          end

          def pipe_for_mono_input(input: [], inject: [], input_filters:, output:, **)
            has_input   = Array(input).any?
            has_filters = has_input || Array(inject).any? || Array(output).any?

                      if has_filters && input_filters.any?
              warn "[Trailblazer] You are mixing `:input` and `In() => ...`. `In()` and Inject () options are ignored and `:input` wins."
              input_filters = []
            end



            pipeline = initial_input_pipeline(add_default_ctx: !has_input)

            if input # FIXME: remove condition
              pipeline = pipe_steps_for_input_option(pipeline, input: input)
            end


            if inject # FIXME: remove condition
              injects = inject.collect { |name| name.is_a?(Symbol) ? [DSL.Inject(), [name]] : [DSL.Inject(), name] }

              tuples  = DSL::Inject.filters_for_injects(injects) # DISCUSS: should we add passthrough/defaulting here at Inject()-time?

              pipeline = add_filter_steps(pipeline, tuples)
            end

            return pipeline, has_filters
          end

          # We allow to inject {:initial_input_pipeline} here in order to skip creating a new input pipeline and instead
          # use the inherit one.
          def pipe_for_composable_input(in_filters: [], inject_filters: [], initial_input_pipeline: initial_input_pipeline_for(in_filters), **)
            inject_filters = DSL::Inject.filters_for_injects(inject_filters) # {Inject() => ...} the pure user input gets translated into AddVariable aggregate steps.
            in_filters     = DSL::Tuple.filters_from_tuples(in_filters)

            # if in_filters.any?
                # With only injections defined, we do not filter out anything, we use the original ctx
                # and _add_ defaulting for injected variables.

                pipeline = add_filter_steps(initial_input_pipeline, in_filters)
                pipeline = add_filter_steps(pipeline, inject_filters)
              # end
              pipeline
          end

          def initial_input_pipeline_for(in_filters)
            is_inject_only = Array(in_filters).empty?

            initial_input_pipeline(add_default_ctx: is_inject_only)
          end

          def add_filter_steps(pipeline, rows) # FIXME: do we need all this?
            rows = add_variables_steps_for_filters(rows)

            adds = Activity::Adds::FriendlyInterface.adds_for(
              rows.collect { |row| [row[1], id: row[0], prepend: "input.scope"] }
            )

            Activity::Adds.apply_adds(pipeline, adds)
          end

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
          def merge_instructions_from_dsl(output:, output_with_outer_ctx:, input_filters:, output_filters:, injects:, **options)

            # The overriding {:input} option is set.
            pipeline, input_overrides = pipe_for_mono_input(input_filters: input_filters, output: output, **options) # FIXME: make this **options

            if ! input_overrides
              pipeline = pipe_for_composable_input(in_filters: input_filters, inject_filters: injects, **options)  # FIXME: rename filters consistently
            end

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input  = Pipe::Input.new(pipeline)

            output = output_for(output: output, output_with_outer_ctx: output_with_outer_ctx, output_filters: output_filters)

# store pipe in the extension (via TW::Extension.data)?
            return TaskWrap::VariableMapping.Extension(input, output, id: input.object_id), # wraps filters: {Input(input), Output(output)}
              {
                variable_mapping_pipelines: [pipeline],
                Linear::Strategy.DataVariable() => :variable_mapping_pipelines # we want to store {:variable_mapping_pipelines} in {Row.data} for later reference.
              }
              # DISCUSS: should we remember the pure pipelines or get it from the compiled extension?
          end


          def output_for(output_with_outer_ctx:, output:, output_filters:)
            steps = [
              ["output.init_hash", VariableMapping.method(:initial_aggregate)],
            ]

            # {:output} option.
            if output
              tuple         = DSL.Out(name: ":output", with_outer_ctx: output_with_outer_ctx) # simulate {Out() => output}
              output_filter = DSL::Tuple.filters_from_tuples([[tuple, output]])

              steps += add_variables_steps_for_filters(output_filter)
            # Out() given.
            elsif output_filters.any?
              out_filters = DSL::Tuple.filters_from_tuples(output_filters)

              # Add one row per filter (either {:output} or {Output()}).
              steps += add_variables_steps_for_filters(out_filters)
            # No Out(), no {:output}.
            else
              # TODO: make this just another output_filter(s)
              steps += [["output.default_output", VariableMapping.method(:default_output_ctx)]]
            end

            steps << ["output.merge_with_original", VariableMapping.method(:merge_with_original)]

            pipe = Activity::TaskWrap::Pipeline.new(steps)

            Pipe::Output.new(pipe)
          end

          # Runtime classes
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


          # Returns array of step rows ("sequence").
          # @param filters [Array] List of {Filter} objects
          def add_variables_steps_for_filters(filters) # FIXME: allow output too!
            filters.collect do |filter|
              ["input.add_variables.#{filter.name}", filter.aggregate_step] # FIXME: config name sucks, of course, if we want to allow inserting etc.
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


          module DSL
            # @param [Array, Hash, Proc] User option coming from the DSL, like {[:model]}
            #
            # Returns a "filter interface" callable that's invoked in {AddVariables}:
            #   filter.(new_ctx, ..., keyword_arguments: new_ctx.to_hash, **circuit_options)
            def self.build_filter(user_filter)
              Trailblazer::Option(filter_for(user_filter))
            end

            # Convert a user option such as {[:model]} to a filter.
            #
            # Returns a filter proc to be called in an Option.
            # @private
            def self.filter_for(filter)
              if filter.is_a?(::Array) || filter.is_a?(::Hash)
                filter_from_dsl(filter)
              else
                filter
              end
            end

            # The returned filter compiles a new hash for Scoped/Unscoped that only contains
            # the desired i/o variables.
            #
            # Filter expects a "filter interface" {(ctx, **)}.
            def self.filter_from_dsl(map)
              hsh = DSL.hash_for(map)

              ->(incoming_ctx, **kwargs) { Hash[hsh.collect { |from_name, to_name| [to_name, incoming_ctx[from_name]] }] }
            end

            def self.hash_for(ary)
              return ary if ary.instance_of?(::Hash)
              Hash[ary.collect { |name| [name, name] }]
            end

            # Keeps user's DSL configuration for a particular io-pipe step.
            # Implements the interface for the actual I/O code and is DSL code happening in the normalizer.
            # The actual I/O code expects {DSL::In} and {DSL::Out} objects to generate the two io-pipes.
            #
            # If a user needs to inject their own private iop step they can create this data structure with desired values here.
            # This is also the reason why a lot of options computation such as {:with_outer_ctx} happens here and not in the IO code.

            class Tuple < Struct.new(:name, :add_variables_class, :filter_builder, :insert_args)
              def self.filters_from_tuples(tuples_to_user_filters)
                tuples_to_user_filters.collect { |tuple, user_filter| tuple.(user_filter) }
              end


              # @return [Filter] Filter instance that keeps {name} and {aggregate_step}.
              def call(user_filter)
                filter         = filter_builder.(user_filter)
                aggregate_step = add_variables_class.new(filter, user_filter)

                VariableMapping::Filter.new(aggregate_step, filter, name, add_variables_class)
              end
            end # TODO: implement {:insert_args}

            # In, Out and Inject are objects instantiated when using the DSL, for instance {In() => [:model]}.
            class In < Tuple; end
            class Out < Tuple; end

            def self.In(name: rand, add_variables_class: AddVariables, filter_builder: method(:build_filter))
              In.new(name, add_variables_class, filter_builder)
            end

# We need DSL::Input/Output objects to find those in the DSL options hash.

            # Builder for a DSL Output() object.
            def self.Out(name: rand, add_variables_class: AddVariables::Output, with_outer_ctx: false, delete: false, filter_builder: method(:build_filter), read_from_aggregate: false)
              add_variables_class = AddVariables::Output::WithOuterContext  if with_outer_ctx
              add_variables_class = AddVariables::Output::Delete            if delete
              filter_builder      = ->(user_filter) { user_filter }         if delete
              add_variables_class = AddVariables::ReadFromAggregate         if read_from_aggregate

              Out.new(name, add_variables_class, filter_builder)
            end

            def self.Inject()
              Inject.new
            end

            # This class is supposed to hold configuration options for Inject().
            class Inject
            # Translate the raw input of the user to {In} tuples
              # {injects}:
              # [[#<Trailblazer::Activity::DSL::Linear::VariableMapping::DSL::Inject:0x0000556e7a206000>, [:date, :time]],
              #  [#<Trailblazer::Activity::DSL::Linear::VariableMapping::DSL::Inject:0x0000556e7a205e48>, {:current_user=>#<Proc:0x0000556e7a205d58 test/docs/variable_mapping_test.rb:601 (lambda)>}]]
              def self.filters_for_injects(injects)
                injects.collect do |inject, user_filter| # iterate all {Inject() => user_filter} calls
                  DSL::Inject.compute_tuples_for_inject(inject, user_filter)
                end.flatten(1)
              end

              # Compute {In} tuples from the user's DSL input.
              # We simply use AddVariables but use our own {inject_filter} which checks if the particular
              # variable is already present in the incoming ctx.
              def self.compute_tuples_for_inject(inject, user_filter) # {user_filter} either [:current_user, :model] or {model: ->{}}
                return tuples_for_array(inject, user_filter) if user_filter.is_a?(Array)
                tuples_for_hash_of_callables(inject, user_filter)
              end

              # [:model, :current_user]
              def self.tuples_for_array(inject, user_filter)
                user_filter.collect do |name|
                  inject_filter = ->(original_ctx, **) { original_ctx.key?(name) ? {name => original_ctx[name]} : {} } # FIXME: make me an {Inject::} method.

                  tuple_for(inject, inject_filter, name, "passthrough")
                end
              end

              # {model: ->(*) { snippet }}
              def self.tuples_for_hash_of_callables(inject, user_filter)
                user_filter.collect do |name, defaulting_filter|
                  inject_filter = ->(original_ctx, **kws) { original_ctx.key?(name) ? {name => original_ctx[name]} : {name => defaulting_filter.(original_ctx, **kws)} }

                  tuple_for(inject, inject_filter, name, "defaulting_callable")
                end
              end

              def self.tuple_for(inject, inject_filter, name, type)
                DSL.In(name: "inject.#{type}.#{name.inspect}", add_variables_class: AddVariables).(inject_filter)
              end
            end
          end # DSL

        end # VariableMapping
      end
    end
  end
end
