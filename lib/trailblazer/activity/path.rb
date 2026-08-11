module Trailblazer
  class Activity
    def self.Path(track_name: :success, normalizers: {step: Path::Normalizer::Step}, **options, &block) # FIXME: test {options}.
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            outputs: {},

            # **options
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

      module Normalizer
        module_function

        def normalize_magnetic_to(ctx, flow_options, _, track_name:, magnetic_to: track_name, **)
          return ctx.merge(magnetic_to: magnetic_to), flow_options
        end

        def add_success_connector(ctx, flow_options, _, connector_semantic:, connector_signal:, track_name:, **)
          helper = DSL::Feature::OutputTuples::Helper

          connectors = {
            helper.Output(connector_semantic, signal: connector_signal) => helper.Track(track_name)
          }

          return connectors.merge(ctx), flow_options
        end

        class AddConnection < Struct.new(:semantic, :signal)
          def call(ctx, flow_options, _, track_name:, **)
            helper = DSL::Feature::OutputTuples::Helper

            connectors = {
              helper.Output(semantic, signal: signal) => helper.Track(track_name) # Translates to Output(:success, Right) => Track(:success)
            }

            return connectors.merge(ctx), flow_options
          end
        end

        circuit = Circuit::Builder.Circuit(
          [:normalize_magnetic_to, method(:normalize_magnetic_to)],
          # [:add_success_connector, method(:add_success_connector)],
          [:add_success_connector, AddConnection.new(:success, Right)],
          # [:add_failure_connector, method(:add_success_connector), merge_to_lib_ctx: {connector_signal: Left, connector_semantic: :failure}],
          [:add_failure_connector, AddConnection.new(:failure, Left)],
        )

        Node = Circuit::Node[:bla_FIXME, circuit, Circuit::Processor]





        # DISCUSS: needs to be global constant so other topologies can use it?
        Step = DSL::Normalizer::Step # canonical normalizer for Path's #step.

        # add the Output() feature:
        # FIXME: move to somewhere else, in dsl.rb.
        Step = Circuit::Adds.(
          Step,
          [
            :normalize_wirings, DSL::Feature::OutputTuples::Normalizer::Node,
            :before, :build_sequence_row
          ],
        )

        # add Path specific behavior:
        Step = Circuit::Adds.(
          Step,
          [
            :add_path_options, Node,
            :before, :normalize_wirings # we're dependent on {OutputTuples}!
          ],
        )
      end # Normalizer

      config.activity, config.builder = Activity.Path() # Activity::Path is just a simple, pre-configured frontend.
    end # Path
  end
end
