module Trailblazer
  class Activity
    module DSL::Linear
      module Normalizer
        module_function

        def activity_normalizer(sequence)
          Trailblazer::Activity::Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            {
            "activity.normalize_context"            => method(:normalize_context),           # last
            "activity.normalize_framework_options"  => method(:merge_framework_options),
            "activity.normalize_for_macro"          => method(:merge_user_options),
            "activity.normalize_step_interface"     => method(:normalize_step_interface),    # first
            },

            sequence_insert: [Linear::Insert.method(:Append), "Start.default"]
          )
        end

        # Specific to the "step DSL": if the first argument is a callable, wrap it in a {step_interface_builder}
        # since its interface expects the step interface, but the circuit will call it with circuit interface.
        def normalize_step_interface((ctx, flow_options), *)
          options = ctx[:options] # either a <#task> or {} from macro

          unless options.is_a?(::Hash)
            task = wrap_with_step_interface(task: options, step_interface_builder: ctx[:user_options][:step_interface_builder]) # TODO: make this optional with appropriate wiring.

            ctx = ctx.merge(options: {task: task})
          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end
        def wrap_with_step_interface(task:, step_interface_builder:)
          step_interface_builder.(task)
        end



        # make ctx[:options] the actual ctx
        def merge_user_options((ctx, flow_options), *)
          options = ctx[:options] # either a <#task> or {} from macro

          ctx = ctx.merge(options: options.merge(ctx[:user_options])) # Note that the user options are merged over the macro options.

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end

        # {:framework_options} such as {:track_name} get overridden by user/macro.
        def merge_framework_options((ctx, flow_options), *)
          framework_options = ctx[:framework_options] # either a <#task> or {} from macro

          ctx = ctx.merge(options: framework_options.merge(ctx[:options])) #

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end

        def normalize_context((ctx, flow_options), *)
          ctx = ctx[:options]

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end
      end


    end # Normalizer
  end
  module Activity::Magnetic
    # One {Normalizer} instance is called for every DSL call (step/pass/fail etc.) and normalizes/defaults
    # the user options, such as setting `:id`, connecting the task's outputs or wrapping the user's
    # task via {TaskBuilder::Binary} in order to translate true/false to `Right` or `Left`.
    #
    # The Normalizer sits in the `@builder`, which receives all DSL calls from the Operation subclass.
    class Normalizer
      def self.build(task_builder: Activity::TaskBuilder.method(:Binary), default_outputs: Builder::Path.default_outputs, pipeline: Pipeline, extension:[], **options)
        return new(
          default_outputs: default_outputs,
          extension:       extension,
          task_builder:    task_builder,
          pipeline:        pipeline,
        ), options
      end

      def initialize(task_builder:, default_outputs:, pipeline:, **options)
        @task_builder    = task_builder
        @default_outputs = default_outputs
        @pipeline        = pipeline # TODO: test me.
        freeze
      end

      def call(task, options)
        ctx = {
          task:            task,
          options:         options,
          task_builder:    @task_builder,
          default_outputs: @default_outputs,
        }

        signal, (ctx, ) = @pipeline.( [ctx], {} )

        return ctx[:options][:task], ctx[:local_options], ctx[:connection_options], ctx[:sequence_options], ctx[:extension_options]
      end

      # needs the basic Normalizer

      # :default_plus_poles is an injectable option.
      module Pipeline
        # extend Trailblazer::Activity::Path( normalizer_class: DefaultNormalizer, plus_poles: PlusPoles.new.merge( Builder::Path.default_outputs.values ) ) # FIXME: the DefaultNormalizer actually doesn't need Left.

        def self.split_options( ctx, task:, options:, ** )
          keywords   = extract_dsl_keywords(options)
          extensions = extract_extensions(options)

           # sort through the "original" user DSL options.
          options, extension_options      = Options.normalize( options, extensions ) # DISCUSS:
          options, local_options          = Options.normalize( options, keywords ) # DISCUSS:
          local_options, sequence_options = Options.normalize( local_options, Activity::Schema::Dependencies.sequence_keywords )

          ctx[:local_options],
          ctx[:connection_options],
          ctx[:sequence_options],
          ctx[:extension_options] = local_options, options, sequence_options, extension_options
        end

        # Filter out connections, e.g. `Output(:fail_fast) => :success` and return only the keywords like `:id` or `:replace`.
        def self.extract_dsl_keywords(options, connection_classes = [Activity::Output, Activity::DSL::OutputSemantic])
          options.keys - options.keys.find_all { |k| connection_classes.include?( k.class ) }
        end

        def self.extract_extensions(options, extensions_classes = [Activity::DSL::Extension])
          options.keys.find_all { |k| extensions_classes.include?( k.class ) }
        end

        # FIXME; why don't we use the extensions passed into the initializer?
        def self.initialize_extension_option( ctx, options:, ** )
          ctx[:options] = options.merge( Activity::DSL::Extension.new( Activity::DSL.method(:record) ) => true )
        end



        # :outputs passed: I know what I want to have connected.
        # no :outputs: use default_outputs
        # ALWAYS connect all outputs to their semantic-color.

        # Create the `plus_poles: <PlusPoles>` tuple where the PlusPoles instance will act as the interface
        # to rewire or add connections for the DSL.
        def self.initialize_plus_poles( ctx, local_options:, default_outputs:, ** )
          outputs = local_options[:outputs] || default_outputs

          ctx[:local_options] =
            {
              plus_poles: PlusPoles.initial(outputs),
            }
            .merge(local_options)
        end

        # task Activity::TaskBuilder::Binary( method(:initialize_extension_option) ), id: "initialize_extension_option"
        # task Activity::TaskBuilder::Binary( method(:normalize_for_macro) ),         id: "normalize_for_macro"

        # task Activity::TaskBuilder::Binary( Activity::TaskWrap::VariableMapping.method(:normalizer_step_for_input_output) )

        # task Activity::TaskBuilder::Binary( method(:split_options) ),              id: "split_options"
        # task Activity::TaskBuilder::Binary( method(:initialize_plus_poles) ),      id: "initialize_plus_poles"
        # task ->((ctx, _), **) { pp ctx; [Activity::Right, [ctx, _]] }
      end
    end # Normalizer
  end
end
