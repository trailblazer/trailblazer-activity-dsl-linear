module Trailblazer
  class Activity
    module DSL
      module Linear
        # Normalizer-steps to implement {:input} and {:output}
        # Returns an Extension instance to be thrown into the `step` DSL arguments.
        def self.VariableMapping(input: nil, output: nil, output_with_outer_ctx: false, inject: [], input_filters: [], output_filters: [], injects: [])
          if output && output_filters.any? # DISCUSS: where does this live?
            warn "[Trailblazer] You are mixing `:output` and `Out() => ...`. `Out()` options are ignored and `:output` wins."
            output_filters = []
          end

          if input && input_filters.any? # DISCUSS: where does this live?
            warn "[Trailblazer] You are mixing `:input` and `In() => ...`. `In()` options are ignored and `:input` wins."
            input_filters = []
          end

          merge_instructions = VariableMapping.merge_instructions_from_dsl(input: input, output: output, output_with_outer_ctx: output_with_outer_ctx, inject: inject, input_filters: input_filters, output_filters: output_filters, injects: injects)

          TaskWrap::Extension(merge: merge_instructions)
        end


# < AddVariables
#   Option
#     filter
#   MergeVariables

        module VariableMapping
          module_function

          Filter = Struct.new(:aggregate_step, :filter, :name, :add_variables_class)

          # For the input filter we
          #   1. create a separate {Pipeline} instance {pipe}. Depending on the user's options, this might have up to four steps.
          #   2. The {pipe} is run in a lamdba {input}, the lambda returns the pipe's ctx[:input_ctx].
          #   3. The {input} filter in turn is wrapped into an {Activity::TaskWrap::Input} object via {#merge_instructions_for}.
          #   4. The {TaskWrap::Input} instance is then finally placed into the taskWrap as {"task_wrap.input"}.
          #
          # @private
          def merge_instructions_from_dsl(input:, output:, output_with_outer_ctx:, inject:, input_filters:, output_filters:, injects:)

            inject_filters = DSL::Inject.filters_for_injects(injects) # {Inject() => ...} the pure user input gets translated into AddVariable aggregate steps.
            in_filters     = DSL::Tuple.filters_from_tuples(input_filters)

            input_steps = [
              ["input.init_hash", VariableMapping.method(:initial_aggregate)],
            ]

            # The overriding {:input} option is set.
            if input
              tuple         = DSL.In(name: ":input") # simulate {In() => input}
              input_filter  = DSL::Tuple.filters_from_tuples([[tuple, input]])

              input_steps += add_variables_steps_for_filters(input_filter)
            # In()
            elsif in_filters.any?
              # With only injections defined, we do not filter out anything, we use the original ctx
              # and _add_ defaulting for injected variables.

              input_steps += add_variables_steps_for_filters(in_filters)
            # No In() or {:input}. Use default ctx, which is the original ctxx.
            else
              input_steps += [["input.default_input", VariableMapping.method(:default_input_ctx)]]
            end

            # Inject filters are just input filters.
            #
            # {inject} can be {[:current_user, :model, {volume: ->() {}, }]}
            if inject.any?
              injects = inject.collect { |name| name.is_a?(Symbol) ? [DSL.Inject(), [name]] : [DSL.Inject(), name] }

              tuples  = DSL::Inject.filters_for_injects(injects) # DISCUSS: should we add passthrough/defaulting here at Inject()-time?

              input_steps += add_variables_steps_for_filters(tuples)
            end

            # add Inject() steps
            input_steps += add_variables_steps_for_filters(inject_filters)

            input_steps << ["input.scope", VariableMapping.method(:scope)]

            pipe = Activity::TaskWrap::Pipeline.new(input_steps)

            # gets wrapped by {VariableMapping::Input} and called there.
            # API: @filter.([ctx, original_flow_options], **original_circuit_options)
            # input = Trailblazer::Option(->(original_ctx, **) {  })
            input = ->((ctx, flow_options), **circuit_options) do # This filter is called by {TaskWrap::Input#call} in the {activity} gem.
              wrap_ctx, _ = pipe.({original_ctx: ctx}, [[ctx, flow_options], circuit_options])

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

            # API in VariableMapping::Output:
            #   output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)
            # Returns {output_ctx} that is used after taskWrap finished.
            output = ->(returned_ctx, (original_ctx, returned_flow_options), **original_circuit_options) {
              wrap_ctx, _ = pipe.({original_ctx: original_ctx, returned_ctx: returned_ctx}, [[original_ctx, returned_flow_options], original_circuit_options])

              wrap_ctx[:aggregate]
            }
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
                aggregate_step = add_variables_class.new(filter)

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
