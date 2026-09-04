module Trailblazer
  class Activity
    def self.Path(normalizers: Path.config.builder.normalizers, helpers: nil, adds: [], **default_options, &block)
      default_options = Path.default_options_for_builder(**default_options)

      activity, builder, helper = DSL.Topology(normalizers: normalizers, adds: adds, default_options: default_options, helper_forwarder: Path.config.helper_forwarder, helpers: helpers) do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
      end

      activity, _ = builder.(&block) if block_given? # FIXME: do that in Topology!    implement for Railway and FastTrack?

      return activity, builder, helper
    end

    class Path < DSL::Topology
      module Normalizer
        module_function

        def normalize_magnetic_to(ctx, flow_options, _, track_name:, magnetic_to: track_name, **)
          return ctx.merge(magnetic_to: magnetic_to), flow_options
        end

        # variable_name_for_track_name is so we don't have to build a new circuit if a track_name changes.
        class AddConnection < Struct.new(:semantic, :signal, :variable_name_for_track_name)
          def call(ctx, flow_options, _, outputs:, **)
            return ctx, flow_options unless outputs.key?(semantic) # Don't add a connector when there's no corresponding output.

            helper = DSL::Feature::OutputTuples::Helper

# puts "@@@@@ #{track_name.inspect}"
            connectors = {
              helper.Output(semantic) => helper.Track(ctx[variable_name_for_track_name]) # Translates to Output(:success, Right) => Track(:success)
            }

            return connectors.merge(ctx), flow_options
          end
        end

        circuit = Circuit::Builder.Circuit(
          [:normalize_magnetic_to, method(:normalize_magnetic_to)],
          # [:add_success_connector, method(:add_success_connector)],
          [:add_success_connector, AddConnection.new(:success, Right, :track_name)],
          # [:add_failure_connector, method(:add_success_connector), merge_to_lib_ctx: {connector_signal: Left, connector_semantic: :failure}],
          [:add_failure_connector, AddConnection.new(:failure, Left, :failure_track_name)],
        )

        Node = Circuit::Node[circuit, Circuit::Processor]
      end # Normalizer

      def self.default_options_for_builder(track_name: :success, **options)
        {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: track_name,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,

            **options
          }
        }
      end

      options = {
        normalizers: {step: DSL::Normalizer::Step},
        # Path always has Wiring API and its own normalizer extensions enabled.
        adds: [
          # add the Output() feature:
          [
            :normalize_wirings, DSL::Feature::OutputTuples::Normalizer::Node,
            :before, :build_task_wrap_node
          ],

          # add Path specific behavior:
          [
            :add_path_options, Normalizer::Node,
            :before, :normalize_wirings # we're dependent on {OutputTuples}!
          ],
        ],
        helpers: {
          DSL::Feature::OutputTuples::Helper => [:Output, :Id, :Track, :Terminus]
        }
      }

      config.activity, config.builder, config.helper_forwarder = Activity.Path(**options) # Activity::Path is just a simple, pre-configured frontend.
      # Trailblazer::Developer.puts(config.builder.normalizers[:step])
      extend config.helper_forwarder # forward Output() and friends to {builder}.
    end # Path
  end
end
