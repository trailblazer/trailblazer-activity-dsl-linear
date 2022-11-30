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

            # Compute pipeline for In() and Inject().
            # We allow to inject {:initial_input_pipeline} here in order to skip creating a new input pipeline and instead
            # use the inherit one.
            def pipe_for_composable_input(in_filters: [], initial_input_pipeline: initial_input_pipeline_for(in_filters), **)
              in_filters  = DSL::Tuple.filters_from_options(in_filters)
              pipeline    = add_filter_steps(initial_input_pipeline, in_filters)
            end

            # initial pipleline depending on whether or not we got any In() filters.
            def initial_input_pipeline_for(in_filters)
              is_inject_only = in_filters.find { |k, v| k.is_a?(VariableMapping::DSL::In) }.nil?

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
              tuple         = DSL.In() # simulate {In() => input}
              input_filter  = DSL::Tuple.filters_from_options([[tuple, input]])

              add_filter_steps(pipeline, input_filter)
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

            class Tuple
              def initialize(variable_name, add_variables_class, filters_builder, add_variables_class_for_callable=nil, insert_args=nil, options={})
                @options =
                  {
                    variable_name:        variable_name,
                    add_variables_class:  add_variables_class,
                    filters_builder:      filters_builder,
                    insert_args:          insert_args,

                    add_variables_class_for_callable: add_variables_class_for_callable,

                    tuple_options: options
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
                def self.call(user_filter, add_variables_class:, add_variables_class_for_callable:, type: :In, **options)
                  # In()/Out() => {:user => :current_user}
                  if user_filter.is_a?(Hash)
                    # For In(): build {SetVariable} filters.
                    # For Out(): build {SetVariable::Output} filters.
                    return Filter.build_filters_for_hash(user_filter, add_variables_class: add_variables_class) do |options, from_name, to_name|
                      options.merge(
                        name:       Filter.name_for(type, "#{from_name.inspect}>#{to_name.inspect}"),
                        read_name:  from_name,
                        write_name: to_name,
                      )
                    end
                  end

                  # In()/Out() => [:current_user]
                  if user_filter.is_a?(Array)
                    user_filter = Filter.hash_for(user_filter)

                    return Filter.build_filters_for_hash(user_filter, add_variables_class: add_variables_class) do |options, from_name, _|
                      options.merge(
                        name:        Filter.name_for(type, from_name.inspect),
                        write_name:  from_name,
                        read_name:   from_name,
                      )
                    end
                  end

                  # callable, producing a hash!
                  filter = Activity::Circuit.Step(user_filter, option: true)

                  [
                    Filter.build_for(
                      name:                 Filter.name_for(type, user_filter.object_id, :add_variables),
                      filter:               filter,
                      write_name:           nil,
                      read_name:            nil,
                      user_filter:          user_filter,
                      add_variables_class:  add_variables_class_for_callable, # for example, {AddVariables::Output}
                      **options
                    )
                  ]
                  # TODO: remove {add_variables_class_for_callable} and make everything SetVariable.
                end # call
              end
            end # In

            class Out < Tuple
              class FiltersBuilder
                def self.call(user_filter, tuple_options:, **options)
                  if tuple_options[:with_outer_ctx]
                    callable    = user_filter # FIXME: :instance_method, for fuck's sake.
                    call_method = callable.respond_to?(:arity) ? callable : callable.method(:call)

                    options =
                      # TODO: remove {if} and only leave {else}.
                      if call_method.arity == 3
                        index = caller_locations.find_index { |location| location.to_s =~ /recompile_activity_for/ }
                        caller_location = caller_locations[index+2]

                        Activity::Deprecate.warn caller_location,
                          "The positional argument `outer_ctx` is deprecated, please use the `:outer_ctx` keyword argument.\n#{VariableMapping.deprecation_link}"

                        options.merge(
                          filter:                           Trailblazer::Option(user_filter),
                          add_variables_class_for_callable: AddVariables::Output::WithOuterContext_Deprecated, # old positional arg
                        )
                      else
                        options.merge(
                          add_variables_class_for_callable: AddVariables::Output::WithOuterContext,
                        )
                      end
                  end

                  In::FiltersBuilder.(user_filter, type: :Out, **options)
                end
              end
            end # Out

            def self.In(variable_name = nil, add_variables_class: SetVariable, filter_builder: In::FiltersBuilder, add_variables_class_for_callable: AddVariables)
              In.new(variable_name, add_variables_class, filter_builder, add_variables_class_for_callable)
            end

            # Builder for a DSL Output() object.
            def self.Out(variable_name = nil, add_variables_class: SetVariable::Output, with_outer_ctx: false, delete: false, filter_builder: Out::FiltersBuilder, read_from_aggregate: false, add_variables_class_for_callable: AddVariables::Output)
              add_variables_class = SetVariable::Output::Delete     if delete
              add_variables_class = SetVariable::ReadFromAggregate  if read_from_aggregate

              Out.new(variable_name, add_variables_class, filter_builder, add_variables_class_for_callable, nil,
                {
                  with_outer_ctx: with_outer_ctx,
                }
              )
            end

            # Used in the DSL by you.
            def self.Inject(variable_name = nil, **)
              Inject.new(
                variable_name,
                nil, # add_variables_class # DISCUSS: do we really want that here?
                Inject::FiltersBuilder
              )
            end

            # This class is supposed to hold configuration options for Inject().
            class Inject < Tuple
              class FiltersBuilder
                # Called via {Tuple#call}
                def self.call(user_filter, add_variables_class:, variable_name:, **options)
                  # Build {SetVariable::Default}
                  if user_filter.is_a?(Hash) # TODO: deprecate in favor if {Inject(:variable_name)}!
                    return Filter.build_filters_for_hash(user_filter, add_variables_class: SetVariable::Default) do |options, from_name, user_proc|
                      options_with_condition_for_defaulted(
                        **options,
                        user_filter:  user_proc,
                        write_name:   from_name,
                        read_name:    from_name,
                      )
                    end
                  end

                  # Build {SetVariable::Conditioned}
                  if user_filter.is_a?(Array)
                    user_filter = Filter.hash_for(user_filter)

                    return Filter.build_filters_for_hash(user_filter, add_variables_class: SetVariable::Conditioned) do |options, from_name, _|
                      options_with_condition(
                        **options,
                        write_name:   from_name,
                        read_name:    from_name,
                        user_filter:  user_filter, # FIXME: this is not really helpful, it's something like [:field, :injects]
                      )
                    end
                  end

                  # Build {SetVariable::Default}
                  # {user_filter} is one of the following
                  # :instance_method
                  options = options_with_condition_for_defaulted(
                    **options,
                    write_name:   variable_name,
                    read_name:    variable_name,
                    user_filter:  user_filter,
                  )

                  [
                    Filter.build_for(add_variables_class: SetVariable::Default, **options)
                  ]
                end # call

                def self.options_with_condition(user_filter:, write_name:, name_specifier: nil, **options)
                  {
                    name:           Filter.name_for(:Inject, write_name.inspect, name_specifier),
                    **options,
                    condition:      VariablePresent.new(variable_name: write_name),
                    write_name:     write_name,
                    user_filter:    user_filter,
                  }
                end

                def self.options_with_condition_for_defaulted(write_name:, user_filter:, **options)
                  default_filter = Activity::Circuit.Step(user_filter, option: true) # this is passed into {SetVariable.new}.

                  options_with_condition(
                    **options,
                    write_name:     write_name,
                    default_filter: default_filter,
                    user_filter:    user_filter,
                    name_specifier: :default,
                  )
                end
              end # FiltersBuilder
            end # Inject

            # DISCUSS: generic, again
            module Filter
              def self.build_for(add_variables_class:, write_name:, read_name:, **options)
                circuit_step_filter = VariableFromCtx.new(variable_name: read_name) # Activity::Circuit.Step(filter, option: true) # this is passed into {SetVariable.new}.

                add_variables_class.new(
                  filter:      circuit_step_filter,
                  write_name:  write_name,
                  **options, # FIXME: same name here for every iteration!
                )
              end

              def self.build_filters_for_hash(user_filter, **options)
                return user_filter.collect do |from_name, to_name|
                  options = yield(options, from_name, to_name)

                  Filter.build_for(
                    user_filter: user_filter,
                    **options,
                  )
                end
              end

              def self.hash_for(ary)
                ary.collect { |name| [name, name] }.to_h
              end

              def self.name_for(type, name, specifier=nil)
                [type, specifier].compact.join(".") + "{#{name}}"
              end
            end # Filter

          end # DSL
        end
      end
    end
  end
end
