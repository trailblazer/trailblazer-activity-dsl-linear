module Trailblazer
  class Activity
    module DSL
      module Linear
        module VariableMapping
          # Code invoked through the normalizer, building runtime structures.
          # Naming
          #   Option: Tuple => user filter
          #   Tuple: #<In ...>
          module DSL
            module_function

            # Compute pipeline for {:input} option.
            def pipe_for_mono_input(input: [], inject: [], in_filters: [], output: [], **)
              has_input              = Array(input).any?
              has_mono_options       = has_input || Array(inject).any? || Array(output).any? # :input, :inject and :output are "mono options".
              has_composable_options = in_filters.any? # DISCUSS: why are we not testing Inject()?

              if has_mono_options && has_composable_options
                warn "[Trailblazer] You are mixing `:input` and `In() => ...`. `In()` and Inject () options are ignored and `:input` wins: #{input} #{inject} #{output} <> #{in_filters} / "
              end

              pipeline = initial_input_pipeline(add_default_ctx: !has_input)
              pipeline = add_steps_for_input_option(pipeline, input: input)
              pipeline = add_steps_for_inject_option(pipeline, inject: inject)

              return pipeline, has_mono_options, has_composable_options
            end

            # Compute pipeline for In() and Inject().
            # We allow to inject {:initial_input_pipeline} here in order to skip creating a new input pipeline and instead
            # use the inherit one.
            def pipe_for_composable_input(in_filters: [], inject_filters: [], initial_input_pipeline: initial_input_pipeline_for(in_filters), **)
              inject_filters = DSL::Tuple.filters_from_options(inject_filters) # {Inject() => ...} the pure user input gets translated into AddVariable aggregate steps.
              in_filters     = DSL::Tuple.filters_from_options(in_filters)

              # With only injections defined, we do not filter out anything, we use the original ctx
              # and _add_ defaulting for injected variables.
              pipeline = add_filter_steps(initial_input_pipeline, in_filters)
              pipeline = add_filter_steps(pipeline, inject_filters, path_prefix: "inject")
            end

            # initial pipleline depending on whether or not we got any In() filters.
            def initial_input_pipeline_for(in_filters)
              is_inject_only = Array(in_filters).empty?

              initial_input_pipeline(add_default_ctx: is_inject_only)
            end


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
            def add_steps_for_input_option(pipeline, input:)
              tuple         = DSL.In(name: ":input") # simulate {In() => input}
              input_filter  = DSL::Tuple.filters_from_options([[tuple, input]])

              add_filter_steps(pipeline, input_filter)
            end


            def pipe_for_mono_output(output_with_outer_ctx: false, output: [], out_filters: [], **)
              # No Out(), no {:output} will result in a default_output_ctx step.
              has_output             = Array(output).any?
              has_mono_options       = has_output
              has_composable_options = Array(out_filters).any?

              if has_mono_options && has_composable_options
                warn "[Trailblazer] You are mixing `:output` and `Out() => ...`. `Out()` options are ignored and `:output` wins."
              end

              pipeline = initial_output_pipeline(add_default_ctx: !has_output)
              pipeline = add_steps_for_output_option(pipeline, output: output, output_with_outer_ctx: output_with_outer_ctx)

              return pipeline, has_mono_options, has_composable_options
            end

            def add_steps_for_output_option(pipeline, output:, output_with_outer_ctx:)
              tuple         = DSL.Out(name: ":output", with_outer_ctx: output_with_outer_ctx) # simulate {Out() => output}
              output_filter = DSL::Tuple.filters_from_options([[tuple, output]])

              add_filter_steps(pipeline, output_filter, prepend_to: "output.merge_with_original", path_prefix: "output")
            end

            def pipe_for_composable_output(out_filters: [], initial_output_pipeline: initial_output_pipeline(add_default_ctx: Array(out_filters).empty?), **)
              out_filters = DSL::Tuple.filters_from_options(out_filters)

              add_filter_steps(initial_output_pipeline, out_filters, prepend_to: "output.merge_with_original", path_prefix: "output")
            end

            def initial_output_pipeline(add_default_ctx: false)
              default_ctx_row =
                add_default_ctx ? Activity::TaskWrap::Pipeline.Row(*default_output_ctx_config) : nil

              Activity::TaskWrap::Pipeline.new(
                [
                  Activity::TaskWrap::Pipeline.Row("output.init_hash", VariableMapping.method(:initial_aggregate)), # very first step
                  default_ctx_row,
                  Activity::TaskWrap::Pipeline.Row("output.merge_with_original", VariableMapping.method(:merge_with_original)), # last step
                ].compact
              )
            end

            def default_output_ctx_config # almost a Row.
              ["output.default_output", VariableMapping.method(:default_output_ctx)]
            end

            def add_steps_for_inject_option(pipeline, inject:)
              injects = inject.collect { |name| name.is_a?(Symbol) ? [DSL.Inject(), [name]] : [DSL.Inject(), name] }

              tuples  = Tuple.filters_from_options(injects) # DISCUSS: should we add passthrough/defaulting here at Inject()-time?

              add_filter_steps(pipeline, tuples, path_prefix: "inject")
            end

            def add_filter_steps(pipeline, rows, prepend_to: "input.scope", path_prefix: "input")
              rows = add_variables_steps_for_filters(rows, path_prefix: path_prefix)

              adds = Activity::Adds::FriendlyInterface.adds_for(
                rows.collect { |row| [row[1], id: row[0], prepend: prepend_to] }
              )

              Activity::Adds.apply_adds(pipeline, adds)
            end

                      # Returns array of step rows ("sequence").
            # @param filters [Array] List of {Filter} objects
            def add_variables_steps_for_filters(filters, path_prefix:)
              filters.collect do |filter|
                ["#{path_prefix}.add_variables.#{filter.name}", filter] # FIXME: config name sucks, of course, if we want to allow inserting etc.
              end
            end


            # Keeps user's DSL configuration for a particular io-pipe step.
            # Implements the interface for the actual I/O code and is DSL code happening in the normalizer.
            # The actual I/O code expects {DSL::In} and {DSL::Out} objects to generate the two io-pipes.
            #
            # If a user needs to inject their own private iop step they can create this data structure with desired values here.
            # This is also the reason why a lot of options computation such as {:with_outer_ctx} happens here and not in the IO code.

            class Tuple # < Struct.new(:name, :add_variables_class, :filters_builder, :insert_args)
              def initialize(name, add_variables_class, filters_builder, add_variables_class_for_callable=nil, insert_args=nil)
                @options =
                  {
                    name:                 name,
                    add_variables_class:  add_variables_class,
                    filters_builder:      filters_builder,
                    insert_args:          insert_args,

                    add_variables_class_for_callable: add_variables_class_for_callable,
                  }
              end

              def to_h
                @options
              end

              def self.filters_from_options(tuples_to_user_filters)
                tuples_to_user_filters.collect { |tuple, user_filter| tuple.(user_filter) }.flatten(1)
              end

              # @return [Filter] Filter instance that keeps {name} and {aggregate_step}.
              def call(user_filter)
                @options[:filters_builder].(user_filter, **to_h)
              end
            end # TODO: implement {:insert_args}

            # In, Out and Inject are objects instantiated when using the DSL, for instance {In() => [:model]}.
            class In < Tuple
              class FiltersBuilder
                def self.call(user_filter, add_variables_class:, add_variables_class_for_callable:, **options)
                  if user_filter.is_a?(Array) # TODO: merge with In::FiltersBuilder
                    user_filter = hash_for(user_filter)
                                                                                        # FIXME
                    return Inject::FiltersBuilder.build_filters_for_hash(user_filter, add_variables_class: add_variables_class) do |options, in_variable, target_name|
                      options.merge(
                        name:           in_variable,
                      )

                    end
                  end

                  if user_filter.is_a?(Hash) # TODO: merge with In::FiltersBuilder
                    return Inject::FiltersBuilder.build_filters_for_hash(user_filter, add_variables_class: add_variables_class) do |options, from_name, to_name|
                      options.merge(
                        name:           from_name,
                        variable_name:  to_name,
                      )
                    end
                  end




                  # callable, producing a hash!

                  # filter = Trailblazer::Option(user_filter) # FIXME: Option or Circuit::Step?
                  filter = Activity::Circuit.Step(user_filter, option: true)

  # FIXME
        filter = Trailblazer::Option(user_filter) if add_variables_class_for_callable == AddVariables::Output::WithOuterContext

                  Inject::FiltersBuilder.build_filters_for_callable(
                    filter,
                    variable_name:        options[:name],
                    user_filter:          user_filter,
                    add_variables_class:  add_variables_class_for_callable, # for example, {AddVariables::Output}
                    **options
                  )
                end

                def self.hash_for(ary)
                  return ary if ary.instance_of?(::Hash) # FIXME: remove
                  Hash[ary.collect { |name| [name, name] }]
                end
              end
            end
            class Out < Tuple; end

            def self.In(name: rand, add_variables_class: SetVariable, filter_builder: In::FiltersBuilder, add_variables_class_for_callable: AddVariables)
              In.new(name, add_variables_class, filter_builder, add_variables_class_for_callable)
            end

            # Builder for a DSL Output() object.
            def self.Out(name: rand, add_variables_class: SetVariable::Output, with_outer_ctx: false, delete: false, filter_builder: In::FiltersBuilder, read_from_aggregate: false, add_variables_class_for_callable: AddVariables::Output)
              add_variables_class_for_callable = AddVariables::Output::WithOuterContext  if with_outer_ctx
              add_variables_class = AddVariables::Output::Delete            if delete
              filter_builder      = ->(user_filter) { user_filter }         if delete
              add_variables_class = AddVariables::ReadFromAggregate         if read_from_aggregate

              Out.new(name, add_variables_class, filter_builder, add_variables_class_for_callable)
            end

            # Used in the DSL by you.
            def self.Inject(variable_name = nil, **)
              Inject.new(
                variable_name,
                SetVariable::Default, # add_variables_class
                Inject::FiltersBuilder
              )
            end

            # This class is supposed to hold configuration options for Inject().
            class Inject < Tuple

#FIXME: naming!


              class FiltersBuilder
                # Called via {Tuple#call}
                def self.call(user_filter, add_variables_class:, **options)
                  if user_filter.is_a?(Hash) # TODO: deprecate in favor if {Inject(:variable_name)}!

                    return build_filters_for_hash(user_filter, add_variables_class: SetVariable::Default) do |options, from_name, user_proc|
                      default_filter      = Activity::Circuit.Step(user_proc, option: true) # this is passed into {SetVariable.new}.

                      options.merge(
                        name:           from_name,
                        condition:      VariablePresent.new(variable_name: from_name),
                        # filter:         circuit_step_filter,
                        default_filter: default_filter,
                        variable_name:  from_name,
                        user_filter:    user_proc,
                      )
                    end
                  end

                  if user_filter.is_a?(Array) # TODO: merge with In::FiltersBuilder
                    user_filter = In::FiltersBuilder.hash_for(user_filter)

                    return build_filters_for_hash(user_filter, add_variables_class: SetVariable::Conditioned) do |options, from_name, _|

                      options.merge(
                        # run our filter if variable is present.
                        condition:      VariablePresent.new(variable_name: from_name),
                        name:           from_name,
                      )

                    end
                  end



                  # {user_filter} is one of the following
                  # :instance_method
                  circuit_step_filter = VariableFromCtx.new(variable_name: options[:name])
                  default_filter      = Activity::Circuit.Step(user_filter, option: true) # this is passed into {SetVariable.new}.

                  build_filters_for_callable(
                    circuit_step_filter,
                    condition:      VariablePresent.new(variable_name: options[:name]),
                    default_filter: default_filter,

                    variable_name:        options[:name],
                    user_filter:          user_filter,
                    add_variables_class:  add_variables_class,
                    **options
                  )
                end # call

                def self.build_filters_for_hash(user_filter, add_variables_class:, **options)
                  return user_filter.collect do |from_name, to_name|
                    options = yield(options, from_name, to_name)

                    circuit_step_filter = VariableFromCtx.new(variable_name: from_name) # Activity::Circuit.Step(filter, option: true) # this is passed into {SetVariable.new}.

                    add_variables_class.new(
                      filter:         circuit_step_filter,
                      variable_name:  from_name, # FIXME: maybe remove this?
                      user_filter:    user_filter,
                      **options, # FIXME: same name here for every iteration!
                    )

                  end
                end

                def self.build_filters_for_callable(filter, add_variables_class:, **options)
                  [
                    add_variables_class.new(
                      filter:         filter,
                      **options,
                    )
                  ]
                end

              end # FiltersBuilder
            end

          end # DSL
        end
      end
    end
  end
end
