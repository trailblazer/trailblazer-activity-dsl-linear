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
            def pipe_for_composable_input(in_filters: [], initial_input_pipeline: initial_input_pipeline_for(in_filters), **)
              in_filters  = DSL::Tuple.filters_from_options(in_filters)  # Compile tuples {In() => ...}  into tw steps.
              _pipeline   = add_filter_steps(initial_input_pipeline, in_filters)
            end

            # initial pipleline depending on whether or not we got any In() filters.
            def initial_input_pipeline_for(in_filters)
              is_inject_only = in_filters.find { |k, v| k.is_a?(VariableMapping::DSL::In) }.nil?

              initial_input_pipeline(add_default_ctx: is_inject_only)
            end

            # Adds the default_ctx step as per option {:add_default_ctx}
            def initial_input_pipeline(add_default_ctx: false)
              # No In() or {:input}. Use default ctx, which is the original ctx.
              # When using Inject without In/:input, we also need a {default_input} ctx.
              pipeline_steps = [
                Activity::TaskWrap::Pipeline.Row("input.scope", VariableMapping.method(:scope)), # last step
              ]

              if add_default_ctx
                pipeline_steps = [
                  Activity::TaskWrap::Pipeline.Row(*default_input_ctx_config),
                  *pipeline_steps
                ]
              end

              Activity::TaskWrap::Pipeline.new(pipeline_steps)
            end

            def default_input_ctx_config # almost a Row.
              ["input.default_input", VariableMapping.method(:default_input_ctx)]
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
              def initialize(variable_name, add_variables_class, filters_builder, insert_args: nil, **options)
                @options =
                  {
                    variable_name:        variable_name,
                    add_variables_class:  add_variables_class,
                    filters_builder:      filters_builder,
                    insert_args:          insert_args,

                    **options
                  }
              end

              def to_h
                @options
              end

              def self.filters_from_options(tuples_to_user_filters)
                tuples_to_user_filters.flat_map { |tuple, user_filter| tuple.(user_filter) }
              end

              # @return [Filter] Filter instance that keeps {name} and {aggregate_step}.
              def call(user_filter)
                @options[:filters_builder].(user_filter, **to_h)
              end
            end # TODO: implement {:insert_args}

            # In, Out and Inject are objects instantiated when using the DSL, for instance {In() => [:model]}.
            #
            # NOTE: do the options processing (such as {:with_outer_ctx}) in the In() method and not in the In object,
            #       as we don't need options once we're in a FiltersBuilder.
            class In < Tuple
              class FiltersBuilder
                def self.call(user_filter, type: :In, **options)
                  # In()/Out() => {:user => :current_user}
                  if user_filter.is_a?(Hash)
                    # For In(): build {SetVariable} filters.
                    # For Out(): build {SetVariable::Output} filters.
                    return Filter.build_filters_for_hash(user_filter, **options) do |options, from_name, to_name|
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

                    return Filter.build_filters_for_hash(user_filter, **options) do |options, from_name, _|
                      options.merge(
                        name:        Filter.name_for(type, from_name.inspect),
                        write_name:  from_name,
                        read_name:   from_name,
                      )
                    end
                  end

                  # callable, producing a hash!
                  build_for_option(
                    user_filter,
                    name:                 Filter.name_for(type, user_filter.object_id, :add_variables),
                    write_name:           nil,
                    read_name:            nil,
                    **options
                  )
                end # call

                # Simply invoke user's filter.
                # Use this for filters without condition and default.
                def self.build_for_option(user_filter, **options)
                  filter = Activity::Circuit.Step(user_filter, option: true)

                  [
                    Filter.build(
                      filter:       filter,
                      user_filter:  user_filter,
                      **options
                    )
                  ]
                end
              end
            end # In

            class Out < Tuple
              class FiltersBuilder
                def self.call(user_filter, **options)
                  In::FiltersBuilder.(user_filter, type: :Out, **options)
                end
              end
            end # Out

            def self.In(variable_name = nil, add_variables_class: SetVariable, filter_builder: In::FiltersBuilder)
              In.new(variable_name, add_variables_class, filter_builder)
            end

            # Builder for a DSL Output() object.
            def self.Out(variable_name = nil, add_variables_class: SetVariable::Output, with_outer_ctx: false, delete: false, filter_builder: Out::FiltersBuilder, read_from_aggregate: false)
              add_variables_class = SetVariable::Output::Delete     if delete
              add_variables_class = SetVariable::ReadFromAggregate  if read_from_aggregate
              add_variables_class = Output::WithOuterContext if with_outer_ctx

              Out.new(
                variable_name,
                add_variables_class,
                filter_builder,
                with_outer_ctx: with_outer_ctx,
              )
            end

            # Used in the DSL by you.
            def self.Inject(variable_name = nil, override: false, filter_builder: Inject::FiltersBuilder, pass_aggregate: false, **)
              add_variables_class = SetVariable::Default
              # FIXME: allow mixing options like :pass_aggregate and :override.
              add_variables_class = SetVariable::PassAggregate if pass_aggregate

              Inject.new(
                variable_name,
                add_variables_class,
                filter_builder,
                override: override,
                pass_aggregate: pass_aggregate,
              )
            end

            # This class is supposed to hold configuration options for Inject().
            class Inject < Tuple
              class FiltersBuilder
                # Called via {Tuple#call}
                def self.call(user_filter, variable_name:, **options)
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
# raise "move into Inject()"
                  if options[:override]
                    return In::FiltersBuilder.build_for_option(
                      user_filter,
                      name:                 Filter.name_for(:Inject, variable_name, :add_variables),
                      write_name:           variable_name,
                      read_name:            nil,
                      **options,
                      add_variables_class:  SetVariable,
                      _FIXME_wrap_with_hash: true,
                    )
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

                  options = Filter.options_for_reading(**options)

                  [
                    Filter.build(**options, _FIXME_wrap_with_hash: true)
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

                def self.options_with_condition_for_defaulted(user_filter:, **options)
                  default_filter = Activity::Circuit.Step(user_filter, option: true) # this is passed into {SetVariable.new}.

                  options_with_condition(
                    **options,
                    user_filter:    user_filter,
                    name_specifier: :default,
                    default_filter: default_filter,
                  )
                end
              end # FiltersBuilder
            end # Inject

            # DISCUSS: generic, again
            module Filter
              def self.build(add_variables_class:, **options)
                add_variables_class.new(
                  **options,
                )
              end

              def self.options_for_reading(read_name:, **options)
                {
                  **options,
                  filter: VariableFromCtx.new(variable_name: read_name),
                }
              end

              def self.build_filters_for_hash(user_filter, **options)
                user_filter.collect do |from_name, to_name|
                  options = yield(options, from_name, to_name)

                  options = options_for_reading(**options)

                  build(
                    **options,
                    user_filter: user_filter,
                    _FIXME_wrap_with_hash: true # FIXME: this is for single variables, as opposed to hash return values that we also support above.
                  )
                end
              end

              def self.hash_for(ary)
                ary.collect { |name| [name, name] }.to_h
              end

              def self.name_for(type, name, specifier = nil)
                [type, specifier].compact.join(".") + "{#{name}}"
              end
            end # Filter
          end # DSL
        end
      end
    end
  end
end
