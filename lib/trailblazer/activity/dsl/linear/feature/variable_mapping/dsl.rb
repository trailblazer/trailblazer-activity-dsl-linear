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
              in_filters_adds  = DSL::Tuple.compile_tuples(in_filters)  # Compile tuples {In() => ...}  into tw steps.

              Activity::Adds.(initial_input_pipeline, *in_filters_adds)
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
              {"input.default_input" => VariableMapping::Runtime.method(:default_input_ctx)}
            end

            def pipe_for_composable_output(out_filters: [], initial_output_pipeline: initial_output_pipeline(add_default_ctx: Array(out_filters).empty?), **)
              out_filters_adds = DSL::Tuple.compile_tuples(out_filters)

              Activity::Adds.(initial_output_pipeline, *out_filters_adds)
            end

# TODO: move to Runtime
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
              def initialize(**options)
                @options = options
              end

              def to_h
                @options
              end

              def self.compile_tuples(tuples)
                tuples.flat_map { |left_option, right_option| call_builder(right_option, **left_option.to_h) }
              end

              # @return [Filter] Filter instance that keeps {name} and {aggregate_step}.
              # Tuple currently is called with the argument from the right-hand side:
              #   Inject(:name) => <right_option>
              # DISCUSS: in OutputTuples, this is called to_a
              def self.call_builder(right_option, builder:, **options)
                builder.(right_option, **options)
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
            end # In

            class Out < Tuple
            end # Out

            def self.In(variable_name = nil, builder: Tuple::Left::In::Builder, insert_args: {prepend: "input.scope"}, path_prefix: "input", **left_user_options)
              In.new(
                variable_name:   variable_name,
                builder:         builder,
                insert_args:     insert_args,
                path_prefix:     path_prefix,
                **left_user_options,
              )
            end

            # Builder for a DSL Output() object.
            def self.Out(variable_name = nil, builder: Tuple::Left::Out::Builder, insert_args: {prepend: "output.merge_with_original"}, path_prefix: "output", **left_user_options)
              Out.new(
                variable_name:   variable_name,
                builder:         builder,
                insert_args:     insert_args,
                path_prefix:     path_prefix,
                **left_user_options,
              )
            end

            # Used in the DSL by you.
            # DISCUSS: should we move the options processing and deciding code into the resp. FiltersBuilder?
            def self.Inject(variable_name = nil, builder: Tuple::Left::Inject::Builder, insert_args: {prepend: "input.scope"}, path_prefix: "inject", **left_user_options)
              Inject.new(
                variable_name: variable_name,
                builder: builder,
                insert_args: insert_args,
                path_prefix: path_prefix,
                **left_user_options,
              )
            end

            # This class is supposed to hold configuration options for Inject().
            #
            # Inject can be 1. "with condition": only add to aggregate if variable is present in original_ctx.
            #               2. "with condition" and default.
            #               3. override: like 2. with a condition always {false}.
            class Inject < Tuple
            end # Inject

            require_relative "runtime/filter_step"
            class Tuple
              module Left # FIXME: new implementation, based on Activity::Railway.
                # Utility methods for translating right-hand options and building filters along with ADDS.
                module Builder
                  def self.hash_for_array(ary)
                    ary.collect { |name| [name, name] }.to_h
                  end

                  def self.build_filter_adds_for_hash(user_hash, **options)
                    user_hash.collect do |from_name, to_name|
                      options_for_build = yield(options, from_name, to_name)

                      circuit_filter = VariableMapping::VariableFromCtx.new(variable_name: from_name)

                      build_filter_step_adds(
                        **options_for_build,
                        filter: circuit_filter,
                      )
                    end
                  end

                  # build a special activity based on {filter_activity}, add all "remaining" options as instance variables.
                  def self.build_filter_step_adds(filter:, filter_activity:, insert_args:, **options_for_build)
                    runtime_step = Runtime::FilterStep.build(
                      filter_activity,
                      filter: filter,
                      **options_for_build
                    )

                    return [runtime_step, id: "FIXME.give.me.a.name", **insert_args]
                  end
                end

                class In
                  # A Builder produces a set of ADDS instructions. Each instruction adds a filter for one or many variables.
                  class Builder
                    # Invoked from {DSL.call_builder}.
                    def self.call(right_option, **options)
                      options = compile_options(right_option, **options)

                      translate_right_option_to_filter_adds(right_option, **options)
                    end

                    # This is options-compiling specific to the left side type.
                    def self.compile_options(right_option, filter_activity: Runtime::FilterStep::MergeVariables, pass_aggregate: false, **options_from_left_option)
                        block_for_filter_step_build = -> {
                          # step :with_outer_ctx, after: :args_for_filter if with_outer_ctx
                          step :pass_aggregate, after: :args_for_filter if pass_aggregate
                        } # FIXME: redundancy.

                        options_from_left_option.merge(
                          filter_activity:             filter_activity,
                          block_for_filter_step_build: block_for_filter_step_build,
                        )
                    end

                    def self.translate_right_option_to_filter_adds(right_option, type: :In, **options)
                      # # In()/Out() => [:current_user]
                      if right_option.is_a?(Array)
                        right_option = Left::Builder.hash_for_array(right_option)
                      end

                      # In()/Out() => {:user => :current_user}
                      if right_option.is_a?(Hash)
                        adds = Left::Builder.build_filter_adds_for_hash(right_option, **options) do |build_adds_options, from_name, to_name|
                          build_adds_options.merge(
                            name:                 Filter.name_for(type, from_name.inspect),
                            write_name:           to_name,
                            read_name:            from_name,
                            wrap_value_with_hash: true,
                          )
                        end

                        return adds
                      end

                      # In()/Out() => ->(*) { snippet }
                      circuit_filter = Activity::Circuit.Step(right_option) # signature is right_option(ctx, **ctx)

                      adds_row = Left::Builder.build_filter_step_adds(
                        filter:       circuit_filter,
                        name:                 Filter.name_for(type, right_option.inspect), # FIXME: name.
                        wrap_value_with_hash: false,
                        **options
                      )

                      return [adds_row]
                    end

                  end
                end # In

                class Out
                  class Builder < In::Builder
                    def self.compile_options(right_option, filter_activity: Runtime::FilterStep::MergeVariables::Output, with_outer_ctx: false, delete: false, read_from_aggregate: false, pass_aggregate: false, **options_from_left_option)

                     filter_activity = Runtime::FilterStep::DeleteFromAggregate if delete

                      # DISCUSS: here, we're using a lot of knowledge about the internals of Runtime::FilterStep in the DSL domain, questionable. let's see.
                      #          because actually we shouldn't know anything about FilterStep and the like here.
                      block_for_filter_step_build = -> {
                        step :with_outer_ctx, after: :args_for_filter if with_outer_ctx
                        step :pass_aggregate, after: :args_for_filter if pass_aggregate
                        step :swap_ctx_with_aggregate, replace: :args_for_filter, id: :args_for_filter if read_from_aggregate
                      }

                      options_from_left_option.merge(
                        filter_activity:             filter_activity,
                        block_for_filter_step_build: block_for_filter_step_build,
                      )
                    end
                  end
                end

                class Inject
                  class Builder < In::Builder
                    def self.compile_options(right_option, filter_activity: Runtime::FilterStep::Conditioned, override: false, pass_aggregate: false, **options_from_left_option)
                      block_for_filter_step_build = -> {
                        # step :with_outer_ctx, after: :args_for_filter if with_outer_ctx
                        step :pass_aggregate, after: :args_for_filter if pass_aggregate
                      } # FIXME: redundancy.

                      options_from_left_option.merge(
                        filter_activity:             filter_activity,
                        block_for_filter_step_build: block_for_filter_step_build,
                        override: override, # DISCUSS: do we want to pass that here?
                      )
                    end

                    def self.translate_right_option_to_filter_adds(right_option, type: :Inject, variable_name:, override:, filter_activity:, **options_from_left_option)
                      # # In()/Out() => [:current_user]
                      if right_option.is_a?(Array)
                        right_option = Left::Builder.hash_for_array(right_option)
                      end

                      # In()/Out() => {:user => :current_user}
                      if right_option.is_a?(Hash)
                        adds = Left::Builder.build_filter_adds_for_hash(right_option, **options_from_left_option) do |build_adds_options, from_name, to_name|

                          # FIXME: this is different to In
                          condition = VariablePresent.new(variable_name: to_name)

                          build_adds_options.merge(
                            name:                 Filter.name_for(type, from_name.inspect),
                            write_name:           to_name,
                            read_name:            from_name,
                            wrap_value_with_hash: true,
                            condition: condition,
                            filter_activity: filter_activity,
                          )
                        end

                        return adds
                      end

                      default_filter = Activity::Circuit.Step(right_option) # signature is right_option(ctx, **ctx)

                      # TODO: override is MergeVariables with filter: default_filter
                      if override
                        adds_row = Left::Builder.build_filter_step_adds(
                          name:   Filter.name_for(type, right_option.inspect), # FIXME: name.
                          wrap_value_with_hash: true,


                          **options_from_left_option,

                          # FIXME: this is different to In
                          filter: default_filter,
                          write_name: variable_name,
                          filter_activity: Runtime::FilterStep::MergeVariables,
                        )

                        return [adds_row]
                      end

                      # Inject(:variable_name) => ->(*) { snippet }
                      filter = VariableMapping::VariableFromCtx.new(variable_name: variable_name)

                        # FIXME: this is different to In
                      condition = VariablePresent.new(variable_name: variable_name)


                      adds_row = Left::Builder.build_filter_step_adds(
                        filter: filter,
                        name:   Filter.name_for(type, right_option.inspect), # FIXME: name.
                        wrap_value_with_hash: true,


                        **options_from_left_option,

                        # FIXME: this is different to In
                        write_name: variable_name,
                        condition: condition,
                        default_filter: default_filter,
                        filter_activity: Runtime::FilterStep::Defaulted,
                      )

                      return [adds_row]
                    end
                  end
                end

              end
            end

            # DISCUSS: generic, again
            module Filter




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
