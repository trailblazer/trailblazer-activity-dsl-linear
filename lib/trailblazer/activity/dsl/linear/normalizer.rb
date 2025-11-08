module Trailblazer
  class Activity
    module DSL
      module Linear
        class KwargsRunner # FIXME: name, location.
          def self.call(task, ctx, flow_options, circuit_options)
            task.(ctx, flow_options, circuit_options, **ctx.to_h) # return ctx, flow_options
          end
        end


        # Normalizers are linear activities that process and normalize the options from a specific DSL call,
        # such as `#step` or `#pass`. All defaulting should happen through the normalizer. An invoked
        # normalizer produces an options hash that has to contain an [:adds] key with a ADDS structure usable
        # for {Sequence.apply_adds}.
        #
        # They're usually invoked from {Strategy#invoke_normalizer_for!}, which is called from {Path#step},
        # {Railway#pass}, etc.
        #
        # Most parts of Normalizer are documented: https://trailblazer.to/2.1/docs/internals.html#internals-dsl-normalizer
        module Normalizer
          # Container for all final normalizers of a specific Strategy.
          class Normalizers
            def initialize(**options)
              @normalizers = options
            end

            # Execute the specific normalizer (step, fail, pass) for a particular option set provided
            # by the DSL user. Usually invoked when you call {#step}.
            def call(name, ctx)
              flow_options = {} # This can be used for tracing, at some point.

              normalizer = @normalizers.fetch(name)

              wrap_ctx, _ = Pipeline.(normalizer, ctx, flow_options, runner: KwargsRunner) # FIXME: experimental feature from {activity}.

              wrap_ctx
            end

            def to_h # FIXME: test me.
              @normalizers
            end
          end

          module_function

          # Helper for normalizers.
          # To be applied on {Pipeline} instances.
          def self.prepend_to(pipe, insertion_id, insertion) # TODO: remove and allow friendly interface.
            instructions = insertion.collect { |id, task| [task, prepend: insertion_id, id: id] }
            instructions = instructions.reverse unless insertion_id

            Adds.(pipe, *instructions)
          end

          # Helper for normalizers.
          def self.replace(pipe, insertion_id, (id, task))
            Adds.(pipe, [task, id: id, replace: insertion_id])
          end

          # Within an activity, Extend a set of normalizers with new steps.
          def self.extend!(activity_class, *step_methods, &block)
            activity_class.instance_variable_get(:@state).update!(:normalizers) do |normalizers|
              apply(normalizers.to_h, *step_methods, &block)
            end
          end

          def self.apply(normalizers_hsh, *step_methods) # TODO: test or make private! we use it in FilterStep!
            new_normalizers = # {step: #<..>, pass: #<..>}
              step_methods.collect do |name|
                extended_normalizer = normalizers_hsh.fetch(name)            # grab existing normalizer.

                new_normalizer = yield(extended_normalizer) # and let the user block change it.

                [name, new_normalizer]
              end.to_h

            Normalizers.new(**normalizers_hsh.merge(new_normalizers))
          end

          # The generic normalizer not tied to `step` or friends.
          def Normalizer(prepend_to_default_outputs: {})
            # Adding steps to the output pipeline means they are only called when there
            # are no :outputs set already.
            outputs_pipeline = Activity::Pipeline(prepend_to_default_outputs)
            # pp outputs_pipeline

            # Call the prepend_to_outputs pipeline only if {:outputs} is not set (by Subprocess).`
            # too bad we don't have nesting here, yet.
            defaults_for_outputs = ->(ctx, flow_options, circuit_options, outputs: nil, **) do
              return ctx, flow_options if outputs

              Pipeline.(outputs_pipeline, ctx, flow_options, circuit_options) # DISCUSS: redundant
            end

            Activity::Pipeline(
              {
                "activity.normalize_step_interface"       => method(:normalize_step_interface),        # Makes sure {:options} is always a hash.
                "activity.macro_options_with_symbol_task" => method(:macro_options_with_symbol_task),  # DISCUSS: we might deprecate {task: :instance_method}

                "activity.merge_library_options"          => method(:merge_library_options),    # Merge "macro"/user options over library options.
                "activity.normalize_for_macro"            => method(:merge_user_options),       # Merge user_options over "macro" options.
                "activity.normalize_normalizer_options"   => method(:merge_normalizer_options), # Merge user_options over normalizer_options.

                "activity.path_helper.forward_block"      => Helper::Path::Normalizer.method(:forward_block_for_path_branch),     # forward the "global" block

                "activity.normalize_context"              => method(:normalize_context),
                "activity.id_with_inherit_and_replace"    => method(:id_with_inherit_and_replace),
                "activity.normalize_id"                   => method(:normalize_id),
                "activity.wrap_task_with_step_interface"  => method(:wrap_task_with_step_interface),

                # Nested pipeline:
                "activity.default_outputs"                => defaults_for_outputs, # only {if :outputs.nil?}

                "inherit.recall_recorded_options"         => Inherit.method(:recall_recorded_options),

                "activity.sequence_insert"                => method(:normalize_sequence_insert),
                "activity.normalize_duplications"         => method(:normalize_duplications),

                "activity.path_helper.path_to_track"      => Helper::Path::Normalizer.method(:convert_paths_to_tracks),


                "output_tuples.normalize_output_tuples"           => OutputTuples.method(:normalize_output_tuples),     # Output(Signal, :semantic) => Id()
                "output_tuples.remember_custom_output_tuples"     => OutputTuples.method(:remember_custom_output_tuples),     # Output(Signal, :semantic) => Id()
                "output_tuples.register_additional_outputs"       => OutputTuples.method(:register_additional_outputs),     # Output(Signal, :semantic) => Id()
                "output_tuples.filter_inherited_output_tuples"    => OutputTuples.method(:filter_inherited_output_tuples),
# raise "move above Output code?"
            # Extension layer
                "extensions.compute_normalizer_extensions" => Extensions.method(:compute_normalizer_extensions),
                "extensions.compile_normalizer_extensions" => Extensions.method(:compile_normalizer_extensions),

                # "step.normalize_task_wrap_extensions" => Normalizer.Task(TaskWrap.method(:normalize_task_wrap_extensions)),
                # here, variable mapping is added.
                "step.add_dsl_extensions_to_task_wrap_extensions" => TaskWrap.method(:add_dsl_extensions_to_task_wrap_extensions), # after this, we got a complete {:task_wrap_extensions} option.
                "step.compile_task_wrap_from_extensions" => TaskWrap.method(:compile_task_wrap_from_extensions),

                "extensions.compile_recorded_extensions"  => Extensions.method(:compile_recorded_extensions), # DISCUSS: WHERE does this go?

                "activity.wirings"                        => OutputTuples::Connections.method(:compile_wirings),



                # DISCUSS: make this configurable? maybe lots of folks don't want {:inherit}?
                "inherit.compile_recorded_options"        => Inherit.method(:compile_recorded_options),

                # TODO: make this a "Subprocess":
                "activity.compile_data" => method(:compile_data),
                "activity.create_row" => method(:create_row),
                "activity.create_add" => method(:create_add),
                "activity.create_adds" => method(:create_adds),
                "activity.apply_adds" => method(:apply_adds)
              }
            )
          end

          # TODO: remove this! it doesn't receive correct ciruit_options.
          # DISCUSS: should we remove this special case?
          # This handles
          #   step task: :instance_method_exposing_circuit_interface
          def macro_options_with_symbol_task(ctx, flow_options, _, options:, **)
            return ctx, flow_options if options[:wrap_task]
            return ctx, flow_options unless options[:task].is_a?(Symbol)

            ctx = ctx.merge(
              options: options.merge(
                wrap_task:              true,
                step_interface_builder: ->(task) { Trailblazer::Option(task) } # only wrap in Option, not {TaskAdapter}.
              )
            )

            return ctx, flow_options
          end

          # @param {:options} The first argument passed to {#step}
          # After this step, options is always a hash.
          #
          # Specific to the "step DSL": if the first argument is a callable, wrap it in a {step_interface_builder}
          # since its interface expects the step interface, but the circuit will call it with circuit interface.
          def normalize_step_interface(ctx, flow_options, _, options:, **)
            return ctx, flow_options if options.is_a?(Hash)

            # Step Interface
            # step :find, ...
            # step Callable, ... (Method, Proc etc)
            ctx = ctx.merge(
                options: {
                  task:       options,
                  wrap_task:  true # task exposes step interface.
                }
              )

            return ctx, flow_options
          end

          # @param :wrap_task If true, the {:task} is wrapped using the step_interface_builder, meaning the
          #                   task is expecting the step interface.
          def wrap_task_with_step_interface(ctx, flow_options, _, step_interface_builder:, task:, wrap_task: false, **)
            return ctx, flow_options unless wrap_task

            ctx = ctx.merge(task: step_interface_builder.(task))

            return ctx, flow_options
          end

          # Wraps {user_step} into a circuit-interface compatible callable, a.k.a. step.
          def build_circuit_step_for_filter(user_step)
            Activity::Circuit.Step(user_step, binary: true)
          end

          def normalize_id(ctx, flow_options, _, task:, id: false, **)
            ctx = ctx.merge(id: id || task)

            return ctx, flow_options
          end

          # {:library_options} such as :sequence, :dsl_track, etc.
          def merge_library_options(ctx, flow_options, _, options:, library_options:, **)
            ctx = ctx.merge(
                options: library_options.merge(options)
              )

            return ctx, flow_options
          end

          # make ctx[:options] the actual ctx
          def merge_user_options(ctx, flow_options, _, options:, user_options:, **)
            # {options} are either a <#task> or {} from macro
            ctx = ctx.merge(
              options: options.merge(user_options) # Note that the user options are merged over the macro options.
            )

            return ctx, flow_options
          end

          # {:normalizer_options} such as {:track_name} get overridden by user/macro.
          def merge_normalizer_options(ctx, flow_options, _, normalizer_options:, options:, **)
            ctx = ctx.merge(
              options: normalizer_options.merge(options)
            )

            return ctx, flow_options
          end

          def normalize_context(ctx, flow_options, _, **)
            ctx = ctx[:options]

            return ctx, flow_options
          end

          # Processes {:before, :after, :replace, :delete} options and
          # defaults to {before: "End.success"} which, yeah.
          def normalize_sequence_insert(ctx, flow_options, _, end_id:, **)
            # Find out whether there's a {before: :model} or anything in the user DSL options.
            insertion = ctx.keys & dsl_insertion_option_to_adds.keys
            insertion = insertion[0]

            insertion, target =
              insertion ? [insertion, ctx[insertion]] : [:before, end_id]
# TODO: test {after: nil}

            adds_insertion = dsl_insertion_option_to_adds[insertion]

            ctx = ctx.merge(
              sequence_insert: {adds_insertion => target}
            )

            return ctx, flow_options
          end

          # Translate DSL option to "friendly interface" option.
          # @private
          # FIXME: make constant.
          def dsl_insertion_option_to_adds
            {
              before:   :prepend,
              after:    :append,
              replace:  :replace,
              delete:   :delete
            }
          end

          def normalize_duplications(ctx, flow_options, _, replace: false, **)
            return ctx, flow_options if replace

            raise_on_duplicate_id(ctx, **ctx.to_hash)
            ctx = clone_duplicate_activity(ctx, **ctx.to_hash)

            return ctx, flow_options
          end

          # @private
          def raise_on_duplicate_id(ctx, id:, sequence:, **)
            raise "ID #{id} is already taken. Please specify an `:id`." if sequence.to_a.find { |row_id, _| row_id == id }
          end

          # @private
          def clone_duplicate_activity(ctx, task:, sequence:, **)
            return ctx unless task.is_a?(Class)
            return ctx unless sequence.to_a.find { |_, row| row.task == task }

            ctx.merge(task: task.clone)
          end

          # Whenever {:replace} and {:inherit} are passed, automatically assign {:id}.
          # DISCUSS: this step could be nested in {inherit_option}.
          def id_with_inherit_and_replace(ctx, flow_options, _, id: nil, replace: nil, inherit: nil, **)
            return ctx, flow_options if id
            return ctx, flow_options unless inherit # inherit: true and inherit: [] both work.
            return ctx, flow_options unless replace

            ctx = ctx.merge(id: replace)

            return ctx, flow_options
          end

          def create_row(ctx, flow_options, _, task:, wirings:, magnetic_to:, data:, task_wrap:nil, **)
            ctx = ctx.merge(
              row: Sequence.Row(
                task: task,
                magnetic_to: magnetic_to,
                wirings: wirings,
                data: data,
                task_wrap: task_wrap
              )
            )

            return ctx, flow_options
          end

          # The {:add} field is one "friendly interface" instruction.
          # See {Adds.call} in the {activity} gem.
          def create_add(ctx, flow_options, _, row:, sequence_insert:, **)
            ctx = ctx.merge(
              add: [
                row,
                id: row.id, # FIXME!
                **sequence_insert
              ]
            )

            return ctx, flow_options
          end

          def create_adds(ctx, flow_options, _, add:, adds:, **)
            ctx = ctx.merge(
              adds: [add] + adds
            )

            return ctx, flow_options
          end

          def apply_adds(ctx, flow_options, _, adds:, sequence:, **)
            ctx[:sequence] = Adds.(sequence, *adds)

            return ctx, flow_options
          end

          # TODO: document DataVariable() => :name
          # Compile data that goes into the sequence row.
          def compile_data(ctx, flow_options, _, default_variables_for_data: [:id, :dsl_track], **)
            variables_for_data = ctx
              .find_all { |k, v| k.instance_of?(Linear::DataVariableName) }
              .flat_map { |k, v| Array(v) }

            ctx = ctx.merge(
              data: (default_variables_for_data + variables_for_data).collect { |key| [key, ctx[key]] }.to_h
            )

            return ctx, flow_options
          end


        end
      end # Normalizer
    end
  end
end
