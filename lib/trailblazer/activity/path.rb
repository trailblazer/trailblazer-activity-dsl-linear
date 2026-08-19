module Trailblazer
  class Activity
    def self.Path(track_name: :success, normalizers: {step: Path::Normalizer::Step}, **options, &block) # FIXME: test {options}.
      builder = DSL::Builder.new(
        normalizers: normalizers,
        default_options: {
          step: {
            magnetic_to:        track_name,
            track_name:         track_name,
            failure_track_name: track_name,
            outputs: DSL::RIGHT_LEFT_OUTPUTS,

            # **options
          },
        }
      )

      activity, _ = builder.() do
        step **DSL.options_for_terminus_step(semantic: :success, terminus_class: Terminus::Success)
      end

      return activity, builder
    end

    class Path < DSL::Topology
      module Normalizer
        module_function

        def normalize_magnetic_to(ctx, flow_options, _, track_name:, magnetic_to: track_name, **)
          return ctx.merge(magnetic_to: magnetic_to), flow_options
        end

        # variable_name_for_track_name is so we don't have to build a new circuit if a track_name changes.
        class AddConnection < Struct.new(:semantic, :signal, :variable_name_for_track_name)
          def call(ctx, flow_options, _, **)
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
