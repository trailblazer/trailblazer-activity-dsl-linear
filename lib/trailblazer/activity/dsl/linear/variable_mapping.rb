module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input: nil, output: nil, output_with_outer_ctx: false, inject: [], input_filters: [], output_filters: [])
          if output && output_filters.any? # DISCUSS: where does this live?
            warn "[Trailblazer] You are mixing `:output` and `Out() => ...`. `Out()` options are ignored and `:output` wins."
            output_filters = []
          end

          if input && input_filters.any? # DISCUSS: where does this live?
            warn "[Trailblazer] You are mixing `:input` and `In() => ...`. `In()` options are ignored and `:input` wins."
            input_filters = []
          end

          merge_instructions = VariableMapping.merge_instructions_from_dsl(input: input, output: output, output_with_outer_ctx: output_with_outer_ctx, inject: inject, input_filters: input_filters, output_filters: output_filters)

          TaskWrap::Extension(merge: merge_instructions)
        end

        module VariableMapping
          module_function

          FilterConfig = Struct.new(:filter, :name, :add_variables_class)

          # For the input filter we
          #   1. create a separate {Pipeline} instance {pipe}. Depending on the user's options, this might have up to four steps.
          #   2. The {pipe} is run in a lamdba {input}, the lambda returns the pipe's ctx[:input_ctx].
          #   3. The {input} filter in turn is wrapped into an {Activity::TaskWrap::Input} object via {#merge_instructions_for}.
          #   4. The {TaskWrap::Input} instance is then finally placed into the taskWrap as {"task_wrap.input"}.
          #
          # @private
          def merge_instructions_from_dsl(input:, output:, output_with_outer_ctx:, inject:, input_filters:, output_filters:)
            # FIXME: this could (should?) be in Normalizer?
            inject_passthrough  = inject.find_all { |name| name.is_a?(Symbol) }
            inject_with_default = inject.find { |name| name.is_a?(Hash) } # FIXME: we only support one default hash in the DSL so far.

            input_steps = [
              ["input.init_hash", VariableMapping.method(:initial_aggregate)],
            ]

            if input
              in_config = DSL.In(name: ":input") # simulate {In() => input}

              input_filters = [DSL.filter_config_for(input, in_config)] + input_filters
            end


            # With only injections defined, we do not filter out anything, we use the original ctx
            # and _add_ defaulting for injected variables.
            if ! input_filters.any? # only injections defined
              input_steps << ["input.default_input", VariableMapping.method(:default_input_ctx)]
            end

            if input_filters.any? # :input or :input/:inject
              # Add one row per filter (either {:input} or {Input()}).
              input_steps += add_variables_steps_for_filters(input_filters)
            end

            if inject_passthrough || inject_with_default
              input_steps << ["input.add_injections", VariableMapping.method(:add_injections)] # we now allow one filter per injected variable.
            end

            if inject_passthrough || inject_with_default
              injections = inject.collect do |name|
                if name.is_a?(Symbol)
                  [[name, Trailblazer::Option(->(*) { [false, name] })]] # we don't want defaulting, this return value signalizes "please pass-through, only".
                else # we automatically assume this is a hash of callables
                  name.collect do |_name, filter|
                    [_name, Trailblazer::Option(->(ctx, **kws) { [true, _name, filter.(ctx, **kws)] })] # filter will compute the default value
                  end
                end
              end.flatten(1).to_h
            end

            input_steps << ["input.scope", VariableMapping.method(:scope)]


            pipe = Activity::TaskWrap::Pipeline.new(input_steps)

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input = ->((ctx, flow_options), **circuit_options) do # This filter is called by {TaskWrap::Input#call} in the {activity} gem.
              wrap_ctx, _ = pipe.({injections: injections, original_ctx: ctx}, [[ctx, flow_options], circuit_options])

              wrap_ctx[:input_ctx]
            end

            # 1. {} empty input hash
            # 1. input # dynamic => hash
            # 2. input_map       => hash
            # 3. inject          => hash
            # 4. Input::Scoped()

            output = output_for(output: output, output_with_outer_ctx: output_with_outer_ctx, output_filters: output_filters)

            TaskWrap::VariableMapping.merge_instructions_for(input, output, id: input.object_id) # wraps filters: {Input(input), Output(output)}
          end

          def output_for(output_with_outer_ctx:, output:, output_filters:)
            steps = [
              ["output.init_hash", VariableMapping.method(:initial_aggregate)],
            ]

            # output_filters = []
            if ! output && output_filters.empty? # no {:output} defined.
              steps << ["output.default_output", VariableMapping.method(:default_output_ctx)]
    # TODO: make this just another output_filter(s)
            end

            # {:output} option
            if output
              out_config = DSL.Out(name: ":input", with_outer_ctx: output_with_outer_ctx) # simulate {Out() => output}

              output_filters << DSL.filter_config_for(output, out_config)
            end



            if output_filters.any? # :input or :input/:inject
              # Add one row per filter (either {:output} or {Output()}).
              steps += add_variables_steps_for_filters(output_filters)
            end


            steps << ["output.merge_with_original", VariableMapping.method(:merge_with_original)]

            pipe = Activity::TaskWrap::Pipeline.new(steps)

            # API in VariableMapping::Output:
            #   output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)
            # Returns {output_ctx} that is used after taskWrap finished.
            output = ->(returned_ctx, (original_ctx, returned_flow_options), **original_circuit_options) {
              wrap_ctx, _ = pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx}, [[original_ctx, returned_flow_options], original_circuit_options])

              wrap_ctx[:aggregate]
            }
          end

          # Returns array of step rows.
          # @param filters [Array] List of {FilterConfig} objects
          def add_variables_steps_for_filters(filter_configs)
            filter_configs.collect do |config|
              # filter = Trailblazer::Option(VariableMapping::filter_for(config.user_filter))

              ["input.add_variables.#{config.name}", config.add_variables_class.new(config.filter)] # FIXME: config name sucks, of course, if we want to allow inserting etc.
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

# TODO: test {nil} default
# FIXME: what if you don't want inject but always the value from the config?
# TODO: use AddVariables here, too, for consistency.
          # Add injected variables if they're present on
          # the original, incoming ctx.
          def add_injections(wrap_ctx, original_args)
            name2filter     = wrap_ctx[:injections]
            ((original_ctx, _), circuit_options) = original_args

            injections =
              name2filter.collect do |name, filter|
                # DISCUSS: should we remove {is_defaulted} and infer type from {filter} or the return value?
                is_defaulted, new_name, default_value = filter.(original_ctx, keyword_arguments: original_ctx.to_hash, **circuit_options) # FIXME: interface?           # {filter} exposes {Option} interface

                original_ctx.key?(name) ?
                  [new_name, original_ctx[name]] : (
                    is_defaulted ? [new_name, default_value] : nil
                  )
              end.compact.to_h # FIXME: are we <2.6 safe here?

            MergeVariables(injections, wrap_ctx, original_args)
          end

          # Input/output Pipeline step that runs the user's {filter} and adds
          # variables to the computed ctx.
          #
          # Basically implements {:input}.
          #
# AddVariables: I call something with an Option-interface and run the return value through MergeVariables().
          # works on {:aggregate} by (usually) producing a hash fragment that is merged with the existing {:aggregate}
          class AddVariables
            def initialize(filter)
              @filter = filter # The users input/output filter.
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
            def self.filter_config_for(user_filter, config)
              filter = config.filter_builder.(user_filter)
              VariableMapping::FilterConfig.new(filter, user_filter.object_id, config.add_variables_class || raise) # FIXME: check should be in In/Our in constructor.
            end

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
            class In < Struct.new(:name, :add_variables_class, :filter_builder, :insert_args); end # TODO: implement {:insert_args}
            class Out < In; end

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
          end

        end # VariableMapping
      end
    end
  end
end
