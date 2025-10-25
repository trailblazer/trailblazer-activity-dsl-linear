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
              in_filters_adds  = DSL::Tuple.compile_tuples_to_filters(in_filters)  # Compile tuples {In() => ...}  into tw steps.

              _pipeline   = Activity::Adds.(initial_input_pipeline, *in_filters_adds)
# pp _pipeline
              _pipeline
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
              pipeline_steps = {
                "input.scope" => VariableMapping::Runtime.method(:build_context), # last step
              }

              if add_default_ctx
                pipeline_steps = default_input_ctx_config.merge(pipeline_steps)
              end

              Activity.Pipeline(pipeline_steps)
            end

            def default_input_ctx_config
              {"input.default_input" => VariableMapping.method(:default_input_ctx)}
            end

            def pipe_for_composable_output(out_filters: [], initial_output_pipeline: initial_output_pipeline(add_default_ctx: Array(out_filters).empty?), **)
              out_filters_adds = DSL::Tuple.compile_tuples_to_filters(out_filters)

              Activity::Adds.(initial_output_pipeline, *out_filters_adds)
            end

            def initial_output_pipeline(add_default_ctx: false)
              default_ctx_row =
                add_default_ctx ? row_for_default_output_ctx : {}

              Activity.Pipeline(
                default_ctx_row
                  .merge("output.merge_with_original" => VariableMapping::Runtime.method(:merge_with_original))
              )
            end

            def row_for_default_output_ctx
              {"output.default_output" => VariableMapping::Runtime.method(:default_output_ctx)}
            end


            # Keeps user's DSL configuration for a particular io-pipe step.
            # Implements the interface for the actual I/O code and is DSL code happening in the normalizer.
            # The actual I/O code expects {DSL::In} and {DSL::Out} objects to generate the two io-pipes.
            #
            # If a user needs to inject their own private iop step they can create this data structure with desired values here.
            # This is also the reason why a lot of options computation such as {:with_outer_ctx} happens here and not in the IO code.

            class Tuple
              def initialize(variable_name, add_variables_class, filters_builder, insert_args: {prepend: "input.scope"}, path_prefix: "input", **options)
                @options =
                  {
                    variable_name:        variable_name,
                    add_variables_class:  add_variables_class,
                    filters_builder:      filters_builder,
                    insert_args:          insert_args,
                    path_prefix:          path_prefix,
                    **options
                  }
              end

              def to_h
                @options
              end

              def self.compile_tuples_to_filters(tuples_to_user_filters)
                tuples_to_user_filters.flat_map { |tuple, user_filter| tuple.(user_filter) }
              end

              # @return [Filter] Filter instance that keeps {name} and {aggregate_step}.
              # Tuple currently is called with the argument from the right-hand side:
              #   Inject(:name) => <right_option>
              #
              # DISCUSS: in OutputTuples, this is called to_a
              # Called by DSL in {#compile_tuples_to_filters}.
              def call(right_option)
                @options[:filters_builder].(right_option, **to_h)
              end
            end # TODO: test {:insert_args}

            # In, Out and Inject are objects instantiated when using the DSL, for instance {In() => [:model]}.
            #
            # NOTE: do the options processing (such as {:with_outer_ctx}) in the In() method and not in the In object,
            #       as we don't need options once we're in a FiltersBuilder.
            #
            #    also, the sooner we complain about a missing or wrong kwarg, the better. Maybe In() should already verify options?
      # raise "could we add, via the DSL in invoke, add an empty In() that doesn't build anything?"
            class In < Tuple
              class FiltersBuilder
                # Called from {Tuple#call}.
                def self.call(user_filter, insert_args:, path_prefix:, **options)
                  filter_steps = translate_tuple_call_to_filters_adds(user_filter, **options)

                  adds_for_filter_steps(filter_steps, insert_args: insert_args, path_prefix: path_prefix)
                end

                def self.adds_for_filter_steps(filter_steps, path_prefix:, insert_args:)
                  filter_steps.collect do |filter|
                    [filter, id: "#{path_prefix}.add_variables.#{filter.object_id}", **insert_args] # FIXME: filter name sucks, of course, if we want to allow inserting etc.
                  end
                end

                # This method disects the different types of user input, eg, hash or array means it builds several filters.
                # TODO: maybe we can improve the separation of disecting and filter creation?
                def self.translate_tuple_call_to_filters_adds(user_filter, type: :In, **options)
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

            def self.In(variable_name = nil, add_variables_class: SetVariable, filters_builder: Tuple::Left::In::Builder, insert_args: {prepend: "input.scope"}, path_prefix: "input")
              In.new(
                variable_name,
                add_variables_class,
                filters_builder,
                insert_args: insert_args,
                path_prefix: path_prefix,
              )
            end

            # Builder for a DSL Output() object.
            def self.Out(variable_name = nil, add_variables_class: SetVariable::Output, with_outer_ctx: false, delete: false, filters_builder: Tuple::Left::Out::Builder, read_from_aggregate: false, insert_args: {prepend: "output.merge_with_original"}, path_prefix: "output")
              add_variables_class = SetVariable::Output::Delete     if delete
              add_variables_class = SetVariable::ReadFromAggregate  if read_from_aggregate
              add_variables_class = Output::WithOuterContext if with_outer_ctx

              Out.new(
                variable_name,
                add_variables_class,
                filters_builder,
                with_outer_ctx: with_outer_ctx,
                insert_args: insert_args,
                path_prefix: path_prefix,
              )
            end

            # Used in the DSL by you.
            # DISCUSS: should we move the options processing and deciding code into the resp. FiltersBuilder?
            def self.Inject(variable_name = nil, filters_builder: Inject::FiltersBuilder, override: false, pass_aggregate: false, insert_args: {prepend: "input.scope"}, path_prefix: "inject", **)
              options = {}
              add_variables_class = SetVariable::Default

              # FIXME: allow mixing options like :pass_aggregate and :override.
              add_variables_class = SetVariable::PassAggregate if pass_aggregate
              options.merge!(condition: ->(*) { false }) if override # an override is a defaulted Inject with condition "always on".

              Inject.new(
                variable_name,
                add_variables_class,
                filters_builder,
                insert_args: insert_args,
                path_prefix: path_prefix,
                **options
              )
            end

            # This class is supposed to hold configuration options for Inject().
            #
            # Inject can be 1. "with condition": only add to aggregate if variable is present in original_ctx.
            #               2. "with condition" and default.
            #               3. override: like 2. with a condition always {false}.
            class Inject < Tuple
              class FiltersBuilder < In::FiltersBuilder
                # Called via {Tuple#call}
                def self.translate_tuple_call_to_filters_adds(user_filter, variable_name:, **options)
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

                def self.options_with_condition(write_name:, name_specifier: nil, condition: VariablePresent.new(variable_name: write_name), **options)
                  {
                    name:           Filter.name_for(:Inject, write_name.inspect, name_specifier),
                    **options,
                    condition:      condition,
                    write_name:     write_name,
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

            require_relative "runtime/filter_step"
            class Tuple
              module Left # FIXME: new implementation, based on Activity::Railway.
                class In
                  class Builder < DSL::In::FiltersBuilder # FIXME: for {.call}.
                    def self.call(user_filter, insert_args:, path_prefix:, **options)
                      translate_tuple_call_to_filters_adds(user_filter, **options)
                    end


                    def self.translate_tuple_call_to_filters_adds(user_filter, type: :In, **options)
                      # 1. how do we know we're In? because we're the filters_builder from In
                      # 2.
                      adds = user_filter.collect do |variable|
                        user_filter = VariableMapping::VariableFromCtx.new(variable_name: variable)
                        filter = user_filter # no Ciruit::Step wrapping as VariableFromCtx exposes circuit-step interface.

                        runtime_step = VariableMapping::Runtime::FilterStep.build(
                          Runtime::FilterStep::MergeVariables,
                          filter:     filter,
                          write_name: variable
                        )

                        [runtime_step, id: variable, prepend: "input.scope"]
                      end

                    end

                  end
                end

                class Out
                  class Builder < In::Builder # FIXME: for {.call}.
                    def self.translate_tuple_call_to_filters_adds(user_filter, type: :In, **options)
# raise "build an :instance filter"
                      if user_filter.is_a?(Symbol) # FIXME: architecture, where do we decide that?
                        filter = Activity::Circuit.Step(user_filter, option: true)

                        runtime_step = VariableMapping::Runtime::FilterStep.build(
                          Runtime::FilterStep::MergeVariables::Output,
                          filter:     filter,
                          wrap_value_with_hash: false
                        )

                        return [[runtime_step, id: "FIXME.give.me.a.name", prepend: "output.merge_with_original"]]
                      end

                      # 1. how do we know we're In? because we're the filters_builder from In
                      # 2.
                      adds = user_filter.collect do |variable|
                        user_filter = VariableMapping::VariableFromCtx.new(variable_name: variable)
                        filter = user_filter # no Ciruit::Step wrapping as VariableFromCtx exposes circuit-step interface.

                        runtime_step = VariableMapping::Runtime::FilterStep.build(
                          Runtime::FilterStep::MergeVariables::Output,
                          filter:     filter,
                          write_name: variable
                        )

                        [runtime_step, id: variable, prepend: "output.merge_with_original"]
                      end
                    end

                  end
                end
              end
            end

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
                  options_for_filter = yield(options, from_name, to_name)

                  options_for_filter = options_for_reading(**options_for_filter)

                  build(
                    **options_for_filter,
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
