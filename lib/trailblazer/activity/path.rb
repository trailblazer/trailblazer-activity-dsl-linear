module Trailblazer
  class Activity
    def self.Path(track_name: :success, &block)
      builder = DSL::Builder.new(
        normalizers: {
          step: DSL::Normalizer::Step, # DISCUSS: make this {DSL::Topology::Normalizer}?
        },
        default_options: {
          step: {
            magnetic_to: track_name,
            # FIXME/TODO: outgoing wiring default?
            track_name: track_name,
            outputs: {},
          },
        }
      )

      options_for_terminus = {
        task:        success_terminus = Trailblazer::Activity::Terminus::Success.new(semantic: track_name),
        wirings:     Path.wirings_for_terminus(signal: success_terminus, semantic: track_name),
        id:          DSL.id_for_terminus(semantic: track_name),
        magnetic_to: track_name
      }

      activity, _ = builder.() do
        step **options_for_terminus
      end

      return activity, builder
    end

    class Path < DSL::Topology
      def self.wirings_for_terminus(signal:, semantic:)
        {
          Output.new(signal, semantic) => DSL::Sequence::Search::Nil.new
        }
      end

      config.activity, config.builder = Activity.Path() # Activity::Path is just a simple, pre-configured frontend.

      module Normalizer
        module_function

        def normalize_magnetic_to(ctx, flow_options, _, track_name:, magnetic_to: track_name, **)
          return ctx.merge(magnetic_to: magnetic_to), flow_options
        end

        def add_success_connector(ctx, flow_options, _, track_name:, **)
          helper = DSL::Feature::OutputTuples::Helper

          connectors = {
            helper.Output(:success, signal: Right) => helper.Track(track_name)
          }

          return connectors.merge(ctx), flow_options
        end

        circuit = Circuit::Builder.Circuit(
          [:normalize_magnetic_to, method(:normalize_magnetic_to)],
          [:add_success_connector, method(:add_success_connector)],
        )

        Node = Circuit::Node[:bla_FIXME, circuit, Circuit::Processor]
      end # Normalizer

    end # Path
  end
end
#       # Functions that help creating a path-specific sequence.
#       module DSL
#         Linear = Activity::DSL::Linear
#         # Always prepend all "add connectors" steps of all normalizers to normalize_output_tuples.
#         # This assures that the order is
#         #   [<default tuples>, <inherited tuples>, <user tuples>]
#         PREPEND_TO = "output_tuples.normalize_output_tuples"

#         module_function

#         def Normalizer(prepend_to_default_outputs: {})
#           path_output_steps = {
#             "path.outputs" => method(:add_success_output)
#           }

#           # Retrieve the base normalizer from {linear/normalizer.rb} and add processing steps.
#           dsl_normalizer = Linear::Normalizer.Normalizer(
#             prepend_to_default_outputs: path_output_steps.merge(prepend_to_default_outputs)
#           )

#           Linear::Normalizer.prepend_to(
#             dsl_normalizer,
#             PREPEND_TO,
#             {
#               "path.step.add_success_connector" => method(:add_success_connector),
#               "path.magnetic_to"                => method(:normalize_magnetic_to),
#             }
#           )
#         end

#         SUCCESS_OUTPUT = {success: Activity::Output(Activity::Right, :success)}

#         def add_success_output(ctx, flow_options, _, **)
#           ctx = ctx.merge(outputs: SUCCESS_OUTPUT)

#           return ctx, flow_options
#         end


#         # This is slow and should be done only once at compile-time,
#         # These are the normalizers for an {Activity}, to be injected into a State.
#         Normalizers = Linear::Normalizer::Normalizers.new(
#           step:     Normalizer(), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
#           terminus: Linear::Normalizer::Terminus.Normalizer(),
#         )

#         # pp Normalizers

#         # DISCUSS: following methods are not part of Normalizer

#         # Default options for {#initialize_options!}.
#         def self.options_for_initialize(track_name: :success, end_task: Trailblazer::Activity::End.new(semantic: :success), end_id: "End.success", **normalizer_options)
#           start = Trailblazer::Activity::Start.new(semantic: :default)

#           {
#             layout_instructions: [
#               [:step, id: "Start.default", task: start, magnetic_to: nil, after: nil, outputs: {success: Activity.Output(Trailblazer::Activity::Right, :success)}], # DISCUSS: technically, we shouldn't have to define only one output here, but it's easier for Railway and FastTrack.
#               [:terminus, id: end_id, task: end_task, magnetic_to: track_name, after: nil],
#             ],

#             normalizers: Normalizers, # see above.

#             # normalizer_options?
#             normalizer_options: {
#               track_name: track_name,

#   # FIXME: needed in #wrap_task_with_step_interface
#               step_interface_builder: Trailblazer::Activity::DSL::Linear::Normalizer.method(:build_circuit_step_for_filter), # DISCUSS: hm, do we want this here in Path, for example?
#   # FIXME: needed in #normalize_sequence_insert
#               end_id: end_id,
#               **normalizer_options
#             }
#           }
#         end
#       end # DSL

#       compile_strategy!(Path::DSL) # sets :normalizer, normalizer_options, sequence and activity on @state.
#     end # Path

#     def self.Path(**kws, &block)
#       Activity::DSL::Linear::Strategy::DSL.Build(Path, **kws, &block)
#     end
#   end
# end
