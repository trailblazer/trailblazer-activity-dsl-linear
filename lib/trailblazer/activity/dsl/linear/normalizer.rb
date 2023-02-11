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
            defaults_for_outputs = -> (ctx, _) do
              return [ctx, _] if ctx.key?(:outputs)

              outputs_pipeline.(ctx, _)
            end

# Normalizers are built on top of Linear::Normalizer.
#
# ## Outputs
# The {:outputs} option is used in the wiring step and dictates the outputs of the step.
# It's either set by Subprocess or by the Strategy's defaulting.
# Note that *if* the option is already set by a macro or user, the entire defaulting described
# here is *not* executed.
#
# ### Defaulting
# There is a special outputs pipeline under {"activity.default_outputs"} which has only one
# responsibility: set {:outputs} if it is not set already.
# Each Strategy subclass now adds its {:outputs} defaulting steps (e.g. {"path.outputs"} or "railway.outputs"
# adding outputs[:failure]) in Railway
# via the Normalizer(prepend_to_default_outputs: ...) keyword argument. In all defaulters (so far)
# the {:outputs} hash is extended.
#
# #### FastTrack
# Adding default outputs only happens if the respective option (e.g. {:pass_fast}) is set.
#
# ## Output Tuples
# Once {:outputs} is finalized, the output tuples (or "connectors") come into play: Output(:success) => Track(:ok)
# First, "activity.inherit_option" will copy over all non-generic tuples to {:non_symbol_options}
#
# Second, the Strategy adds its default connectors. This usually happens by prepending the defaulting
# steps to "activity.normalize_output_tuples" (defined via {Path::DSL::PREPEND_TO}).
# Alternatively, as with "railway.fail.success_to_failure", a particular "inherited" connector step is replaced.
# This assures that the order in {:non_symbol_options} and the resulting order of {:output_tuples} is
#   [<default tuples>, <inherited tuples>, <user tuples>]

# Third, user tuples are merged on top.
#
# Normalization starts where
#   * the {:outputs} hash might get extended if using Output(NewSignal, :semantic)
#   * some inherited tuples might be removed (TODO: maybe more here)
#
# The outcome is {:output_tuples} that matches the {:outputs} and can be transformed into {:wirings}

# ## Test structure
# wiring_api_test.rb Output(...) =>
#   inherit tests are in step_test



            pipeline = TaskWrap::Pipeline.new(
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
                "activity.default_outputs"           => defaults_for_outputs, # only {if :outputs.nil?}

                "inherit.recall_recorded_options"                 => Normalizer.Task(Inherit.method(:recall_recorded_options)),
                "activity.sequence_insert"                => Normalizer.Task(method(:normalize_sequence_insert)),
                "activity.normalize_duplications"         => Normalizer.Task(method(:normalize_duplications)),

                "activity.path_helper.path_to_track"       => Normalizer.Task(Helper::Path::Normalizer.method(:convert_paths_to_tracks)),


                "activity.normalize_output_tuples"        => Normalizer.Task(OutputTuples.method(:normalize_output_tuples)),     # Output(Signal, :semantic) => Id()
                "activity.remember_custom_output_tuples"        => Normalizer.Task(OutputTuples.method(:remember_custom_output_tuples)),     # Output(Signal, :semantic) => Id()
                "activity.register_additional_outputs"      => Normalizer.Task(OutputTuples.method(:register_additional_outputs)),     # Output(Signal, :semantic) => Id()
                "activity.filter_inherited_output_tuples"   => Normalizer.Task(OutputTuples.method(:filter_inherited_output_tuples)),
                # ...
                 # FIXME: rename!
                "activity.normalize_outputs_from_dsl" => Normalizer.Task(method(:normalize_connections_from_dsl)),

                "activity.wirings"                            => Normalizer.Task(method(:compile_wirings)),

                # DISCUSS: make this configurable? maybe lots of folks don't want {:inherit}?
                "inherit.compile_recorded_options" => Normalizer.Task(Inherit.method(:compile_recorded_options)),

                # TODO: make this a "Subprocess":
                "activity.compile_data" => Normalizer.Task(method(:compile_data)),
                "activity.create_row" => Normalizer.Task(method(:create_row)),
                "activity.create_add" => Normalizer.Task(method(:create_add)),
                "activity.create_adds" => Normalizer.Task(method(:create_adds)),
              }.
                collect { |id, task| TaskWrap::Pipeline.Row(id, task) }
            )

            pipeline
          end

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
          def wrap_task_with_step_interface(ctx, wrap_task: false, step_interface_builder:, task:, **)
            return unless wrap_task

            ctx[:task] = step_interface_builder.(task)
          end

          def normalize_id(ctx, id: false, task:, **)
            ctx[:id] = id || task
          end

          # TODO: remove {#normalize_override} in 1.2.0.
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

          # Compile the actual {Seq::Row}'s {wiring}.
          # This combines {:connections} and {:outputs}
          def compile_wirings(ctx, connections:, outputs:, id:, **)
            ctx[:wirings] =
              connections.collect do |semantic, (search_strategy_builder, *search_args)|
                output = outputs[semantic] || raise("No `#{semantic}` output found for #{id.inspect} and outputs #{outputs.inspect}")

                search_strategy_builder.( # return proc to be called when compiling Seq, e.g. {ById(output, :id)}
                  output,
                  *search_args
                )
              end
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
              :before  => :Prepend,
              :after   => :Append,
              :replace => :Replace,
              :delete  => :Delete,
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

          # Process {Output(:semantic) => target} and make them {:connections}.
          def normalize_connections_from_dsl(ctx, adds:, output_tuples:, sequence:, normalizers:, **)
            # Find all {Output() => Track()/Id()/End()}
            return unless output_tuples.any?

            connections = {}

            # DISCUSS: how could we add another magnetic_to to an end?
            output_tuples.each do |output, cfg|
              new_connections, add =
                if cfg.is_a?(Linear::Track)
                  [output_to_track(ctx, output, cfg), cfg.adds] # FIXME: why does Track have a {adds} field? we don't use it anywhere.
                elsif cfg.is_a?(Linear::Id)
                  [output_to_id(ctx, output, cfg.value), []]
                elsif cfg.is_a?(Activity::End)
                  end_id     = Activity::Railway.end_id(**cfg.to_h)
                  end_exists = Activity::Adds::Insert.find_index(ctx[:sequence], end_id)

                  _adds = end_exists ? [] : add_terminus(cfg, id: end_id, sequence: sequence, normalizers: normalizers)

                  [output_to_id(ctx, output, end_id), _adds]
                else
                  raise cfg.inspect
                end

              connections = connections.merge(new_connections)
              adds += add
            end

            ctx[:connections] = connections
            ctx[:adds]        = adds
          end

          def output_to_track(ctx, output, track)
            search_strategy = track.options[:wrap_around] ? :WrapAround : :Forward

            {output.semantic => [Linear::Sequence::Search.method(search_strategy), track.color]}
          end

          def output_to_id(ctx, output, target)
            {output.semantic => [Linear::Sequence::Search.method(:ById), target]}
          end

          # Returns ADDS for the new terminus.
          def add_terminus(end_event, id:, sequence:, normalizers:)
            step_options = Linear::Sequence::Builder.invoke_normalizer_for(:terminus, end_event, {id: id}, sequence: sequence, normalizer_options: {}, normalizers: normalizers)

            step_options[:adds]
          end


          module OutputTuples
            # Logic related to {Output() => ...}, called "Wiring API".
            # TODO: move to different namespace (feature/dsl)
            def self.Output(semantic, is_generic: true)
              Normalizer::OutputTuples::Output::Semantic.new(semantic, is_generic)
            end

            module Output
              # Note that both {Semantic} and {CustomOutput} are {kind_of?(Output)}
              Semantic      = Struct.new(:semantic, :generic?).include(Output)
              CustomOutput  = Struct.new(:signal, :semantic, :generic?).include(Output) # generic? is always false
            end


            # 1. remember custom tuples (Output and output_semantic)
            # 2. convert Output, and add to :outputs
            # 3. now OutputSemantic only to be treated

            def self.normalize_output_tuples(ctx, non_symbol_options:, **)
              output_tuples = non_symbol_options.find_all { |k,v| k.is_a?(OutputTuples::Output) }

              ctx.merge!(output_tuples: output_tuples)
            end

            # Remember all custom (non-generic) {:output_tuples}.
            def self.remember_custom_output_tuples(ctx, output_tuples:, non_symbol_options:, **)
              # We don't include generic OutputSemantic (from Subprocess(strict: true)) for inheritance, as this is not a user customization.
              custom_output_tuples = output_tuples.reject { |k,v| k.generic? }

              # save Output() tuples under {:custom_output_tuples} for inheritance.
              ctx.merge!(
                non_symbol_options: non_symbol_options.merge(
                  Normalizer::Inherit.Record(custom_output_tuples.to_h, type: :custom_output_tuples) => nil,
                )
              )
            end

            # Take all Output(signal, semantic), convert to OutputSemantic and extend {:outputs}.
            # Since only users use this style, we don't have to filter.
            def self.register_additional_outputs(ctx, output_tuples:, outputs:, **)
              # We need to preserve the order when replacing Output with OutputSemantic,
              # that's why we recreate {output_tuples} here.
              output_tuples =
                output_tuples.collect do |(output, connector)|
                  if output.kind_of?(Output::CustomOutput)
                    # add custom output to :outputs.
                    outputs = outputs.merge(output.semantic => Activity.Output(output.signal, output.semantic))

                    # Convert Output to OutputSemantic.
                    [Strategy.Output(output.semantic), connector]
                  else
                    [output, connector]
                  end
                end

              ctx.merge!(
                output_tuples: output_tuples,
                outputs:            outputs
              )
            end

            # 1. :outputs is provided by DSL
# 2. IF :inherit => copy inherited Output tuples
# 3. convert Output (without semantic, btw, change that) and add to :outputs
# 4. IF :inherit and strict == false (in step-options,not Subprocess) => throw out Output with unknown semantic

            # Implements {inherit: :outputs, strict: false}
            # return connections from {parent} step which are supported by current step
            def self.filter_inherited_output_tuples(ctx, inherit: false, inherited_recorded_options: {}, outputs:, output_tuples:, **)
              return unless inherit === true
              strict_outputs = false # TODO: implement "strict outputs" for inherit! meaning we connect all inherited Output regardless of the new activity's interface
              return if strict_outputs === true

              # Grab the inherited {:custom_output_tuples} so we can throw those out if the new activity doesn't support
              # the respective outputs.
              inherited_output_tuples_record  = inherited_recorded_options[:custom_output_tuples]
              inherited_output_tuples         = inherited_output_tuples_record ? inherited_output_tuples_record.options : {}

              allowed_semantics     = outputs.keys # these outputs are exposed by the inheriting step.
              inherited_semantics   = inherited_output_tuples.collect { |output, _| output.semantic }
              unsupported_semantics = inherited_semantics - allowed_semantics

              filtered_output_tuples = output_tuples.reject do |output, _| unsupported_semantics.include?(output.semantic) end

              ctx.merge!(
                output_tuples: filtered_output_tuples.to_h
              )
            end

            # we want this in the end:
            # {output.semantic => search strategy}
            def convert____connections

            end
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
          def compile_data(ctx, default_variables_for_data: [:id, :dsl_track, :connections, :extensions, :stop_event], non_symbol_options:, **)
            variables_for_data = non_symbol_options.find_all { |k,v| k.instance_of?(Linear::DataVariableName) }.collect { |k,v| Array(v) }.flatten

            ctx[:data] = (default_variables_for_data + variables_for_data).collect { |key| [key, ctx[key]] }.to_h
          end
        end

      end # Normalizer
    end
  end
end
