module Trailblazer
  class Activity
    module DSL
      module Linear
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
              normalizer = @normalizers.fetch(name)
              wrap_ctx, _ = normalizer.(ctx, nil)
              wrap_ctx
            end
          end

          module_function

          # Helper for normalizers.
          # To be applied on {Pipeline} instances.
          def self.prepend_to(pipe, insertion_id, insertion)
            adds =
              insertion.collect do |id, task|
                {insert: [Adds::Insert.method(:Prepend), insertion_id], row: Activity::TaskWrap::Pipeline.Row(id, task)}
              end

            Adds.apply_adds(pipe, insertion_id ? adds : adds.reverse)
          end

          # Helper for normalizers.
          def self.replace(pipe, insertion_id, (id, task))
            Adds.apply_adds(
              pipe,
              [{insert: [Adds::Insert.method(:Replace), insertion_id], row: Activity::TaskWrap::Pipeline.Row(id, task)}]
            )
          end

          # Extend a particular normalizer with new steps and save it on the activity.
          def self.extend!(activity_class, *step_methods)
            activity_class.instance_variable_get(:@state).update!(:normalizers) do |normalizers|
              hsh = normalizers.instance_variable_get(:@normalizers) # TODO: introduce {#to_h}.

              new_normalizers = # {step: #<..>, pass: #<..>}
                step_methods.collect do |name|
                  extended_normalizer = hsh.fetch(name)            # grab existing normalizer.
                  new_normalizer      = yield(extended_normalizer) # and let the user block change it.
                  [name, new_normalizer]
                end.to_h

              Normalizers.new(**hsh.merge(new_normalizers))
            end
          end

          # Wrap user's normalizer task in a {Pipeline::TaskAdapter} so it executes with
          # convenient kw args.
          #
          # Example
          #   normalizer_task = Normalizer.Task(method(:normalize_id))
          #
          #   # will call {normalizer_task} and pass ctx variables as kwargs, as follows
          #   def normalize_id(ctx, id: false, task:, **)
          def Task(user_step)
            Activity::TaskWrap::Pipeline::TaskAdapter.for_step(user_step, option: false) # we don't need Option as we don't have ciruit_options here, and no {:exec_context}
          end

          # The generic normalizer not tied to `step` or friends.
          def Normalizer(prepend_to_default_outputs: [])
            # Adding steps to the output pipeline means they are only called when there
            # are no :outputs set already.
            outputs_pipeline = TaskWrap::Pipeline.new([])
            prepend_to_default_outputs.each do |hsh|
              outputs_pipeline = Linear::Normalizer.prepend_to(outputs_pipeline, nil, hsh) # DISCUSS: does it matter if we prepend FastTrack to Railway, etc?
            end

            # Call the prepend_to_outputs pipeline only if {:outputs} is not set (by Subprocess).
            # too bad we don't have nesting here, yet.
            defaults_for_outputs = ->(ctx, args) do
              return [ctx, args] if ctx.key?(:outputs)

              outputs_pipeline.(ctx, args)
            end

            TaskWrap::Pipeline.new(
              {
                "activity.normalize_step_interface"       => Normalizer.Task(method(:normalize_step_interface)),        # Makes sure {:options} is always a hash.
                "activity.macro_options_with_symbol_task" => Normalizer.Task(method(:macro_options_with_symbol_task)),  # DISCUSS: we might deprecate {task: :instance_method}

                "activity.merge_library_options"          => Normalizer.Task(method(:merge_library_options)),    # Merge "macro"/user options over library options.
                "activity.normalize_for_macro"            => Normalizer.Task(method(:merge_user_options)),       # Merge user_options over "macro" options.
                "activity.normalize_normalizer_options"   => Normalizer.Task(method(:merge_normalizer_options)), # Merge user_options over normalizer_options.
                "activity.normalize_non_symbol_options"   => Normalizer.Task(method(:normalize_non_symbol_options)),
                "activity.path_helper.forward_block"      => Normalizer.Task(Helper::Path::Normalizer.method(:forward_block_for_path_branch)),     # forward the "global" block
                "activity.normalize_context"              => method(:normalize_context),
                "activity.id_with_inherit_and_replace"    => Normalizer.Task(method(:id_with_inherit_and_replace)),
                "activity.normalize_id"                   => Normalizer.Task(method(:normalize_id)),
                "activity.normalize_override"             => Normalizer.Task(method(:normalize_override)), # TODO: remove!
                "activity.wrap_task_with_step_interface"  => Normalizer.Task(method(:wrap_task_with_step_interface)),

                # Nested pipeline:
                "activity.default_outputs"                => defaults_for_outputs, # only {if :outputs.nil?}

                "extensions.convert_extensions_option_to_tuples" => Normalizer.Task(Extensions.method(:convert_extensions_option_to_tuples)),

                "inherit.recall_recorded_options"         => Normalizer.Task(Inherit.method(:recall_recorded_options)),
                "activity.sequence_insert"                => Normalizer.Task(method(:normalize_sequence_insert)),
                "activity.normalize_duplications"         => Normalizer.Task(method(:normalize_duplications)),

                "activity.path_helper.path_to_track"      => Normalizer.Task(Helper::Path::Normalizer.method(:convert_paths_to_tracks)),


                "output_tuples.normalize_output_tuples"           => Normalizer.Task(OutputTuples.method(:normalize_output_tuples)),     # Output(Signal, :semantic) => Id()
                "output_tuples.remember_custom_output_tuples"     => Normalizer.Task(OutputTuples.method(:remember_custom_output_tuples)),     # Output(Signal, :semantic) => Id()
                "output_tuples.register_additional_outputs"       => Normalizer.Task(OutputTuples.method(:register_additional_outputs)),     # Output(Signal, :semantic) => Id()
                "output_tuples.filter_inherited_output_tuples"    => Normalizer.Task(OutputTuples.method(:filter_inherited_output_tuples)),

                "activity.wirings"                        => Normalizer.Task(OutputTuples::Connections.method(:compile_wirings)),


                "extensions.compile_extensions"           => Normalizer.Task(Extensions.method(:compile_extensions)),
                "extensions.compile_recorded_extensions"  => Normalizer.Task(Extensions.method(:compile_recorded_extensions)),

                # DISCUSS: make this configurable? maybe lots of folks don't want {:inherit}?
                "inherit.compile_recorded_options"        => Normalizer.Task(Inherit.method(:compile_recorded_options)),

                # TODO: make this a "Subprocess":
                "activity.compile_data" => Normalizer.Task(method(:compile_data)),
                "activity.create_row" => Normalizer.Task(method(:create_row)),
                "activity.create_add" => Normalizer.Task(method(:create_add)),
                "activity.create_adds" => Normalizer.Task(method(:create_adds)),
              }
                .collect { |id, task| TaskWrap::Pipeline.Row(id, task) }
            )
          end

          # TODO: remove this! it doesn't receive correct ciruit_options.
          # DISCUSS: should we remove this special case?
          # This handles
          #   step task: :instance_method_exposing_circuit_interface
          def macro_options_with_symbol_task(ctx, options:, **)
            return if options[:wrap_task]
            return unless options[:task].is_a?(Symbol)

            ctx[:options] = {
              **options,
              wrap_task:              true,
              step_interface_builder: ->(task) { Trailblazer::Option(task) } # only wrap in Option, not {TaskAdapter}.
            }
          end

          # @param {:options} The first argument passed to {#step}
          # After this step, options is always a hash.
          #
          # Specific to the "step DSL": if the first argument is a callable, wrap it in a {step_interface_builder}
          # since its interface expects the step interface, but the circuit will call it with circuit interface.
          def normalize_step_interface(ctx, options:, **)
            return if options.is_a?(Hash)

            # Step Interface
            # step :find, ...
            # step Callable, ... (Method, Proc etc)
            ctx[:options] = {
              task:       options,
              wrap_task:  true # task exposes step interface.
            }
          end

          # @param :wrap_task If true, the {:task} is wrapped using the step_interface_builder, meaning the
          #                   task is expecting the step interface.
          def wrap_task_with_step_interface(ctx, step_interface_builder:, task:, wrap_task: false, **)
            return unless wrap_task

            ctx[:task] = step_interface_builder.(task)
          end

          def normalize_id(ctx, task:, id: false, **)
            ctx[:id] = id || task
          end

          # TODO: remove {#normalize_override} in 1.2.0 (Used in macro-contract tests).
          # {:override} really only makes sense for {step Macro(), {override: true}} where the {user_options}
          # dictate the overriding.
          def normalize_override(ctx, id:, override: false, **)
            return unless override

            Activity::Deprecate.warn Linear::Deprecate.dsl_caller_location, "The :override option is deprecated and will be removed. Please use :replace instead."

            ctx[:replace] = (id || raise)
          end

          # {:library_options} such as :sequence, :dsl_track, etc.
          def merge_library_options(ctx, options:, library_options:, **)
            ctx[:options] = library_options.merge(options)
          end

          # make ctx[:options] the actual ctx
          def merge_user_options(ctx, options:, user_options:, **)
            # {options} are either a <#task> or {} from macro
            ctx[:options] = options.merge(user_options) # Note that the user options are merged over the macro options.
          end

          # {:normalizer_options} such as {:track_name} get overridden by user/macro.
          def merge_normalizer_options(ctx, normalizer_options:, options:, **)
            ctx[:options] = normalizer_options.merge(options)
          end

          def normalize_context(ctx, flow_options)
            ctx = ctx[:options]

            return ctx, flow_options
          end

          # Processes {:before,:after,:replace,:delete} options and
          # defaults to {before: "End.success"} which, yeah.
          def normalize_sequence_insert(ctx, end_id:, **)
            insertion = ctx.keys & sequence_insert_options.keys
            insertion = insertion[0]   || :before
            target    = ctx[insertion] || end_id

            insertion_method = sequence_insert_options[insertion]

            ctx[:sequence_insert] = [Activity::Adds::Insert.method(insertion_method), target]
          end

          # @private
          def sequence_insert_options
            {
              before:   :Prepend,
              after:    :Append,
              replace:  :Replace,
              delete:   :Delete
            }
          end

          def normalize_duplications(ctx, replace: false, **)
            return if replace

            raise_on_duplicate_id(ctx, **ctx)
            clone_duplicate_activity(ctx, **ctx) # DISCUSS: mutates {ctx}.
          end

          # @private
          def raise_on_duplicate_id(ctx, id:, sequence:, **)
            raise "ID #{id} is already taken. Please specify an `:id`." if sequence.find { |row| row.id == id }
          end

          # @private
          def clone_duplicate_activity(ctx, task:, sequence:, **)
            return unless task.is_a?(Class)

            ctx[:task] = task.clone if sequence.find { |row| row[1] == task }
          end

          # Move DSL user options such as {Output(:success) => Track(:found)} to
          # a new key {options[:non_symbol_options]}.
          # This allows using {options} as a {**ctx}-able hash in Ruby 2.6 and 3.0.
          def normalize_non_symbol_options(ctx, options:, **)
            symbol_options     = options.find_all { |k, v| k.is_a?(Symbol) }.to_h
            non_symbol_options = options.slice(*(options.keys - symbol_options.keys))
            # raise unless (symbol_options.size+non_symbol_options.size) == options.size

            ctx[:options] = symbol_options.merge(non_symbol_options: non_symbol_options)
          end

          # Whenever {:replace} and {:inherit} are passed, automatically assign {:id}.
          # DISCUSS: this step could be nested in {inherit_option}.
          def id_with_inherit_and_replace(ctx, id: nil, replace: nil, inherit: nil, **)
            return if id
            return unless inherit # inherit: true and inherit: [] both work.
            return unless replace

            ctx[:id] = replace
          end

          def create_row(ctx, task:, wirings:, magnetic_to:, data:, **)
            ctx[:row] = Sequence.create_row(task: task, magnetic_to: magnetic_to, wirings: wirings, **data)
          end

          def create_add(ctx, row:, sequence_insert:, **)
            ctx[:add] = {row: row, insert: sequence_insert}
          end

          def create_adds(ctx, add:, adds:, **)
            ctx[:adds] = [add] + adds
          end

          # TODO: document DataVariable() => :name
          # Compile data that goes into the sequence row.
          def compile_data(ctx, non_symbol_options:, default_variables_for_data: [:id, :dsl_track, :extensions], **)
            variables_for_data = non_symbol_options
              .find_all { |k, v| k.instance_of?(Linear::DataVariableName) }
              .flat_map { |k, v| Array(v) }

            ctx[:data] = (default_variables_for_data + variables_for_data).collect { |key| [key, ctx[key]] }.to_h
          end
        end
      end # Normalizer
    end
  end
end
