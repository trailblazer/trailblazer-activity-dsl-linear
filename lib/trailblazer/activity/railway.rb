module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    def self.Railway(options={})
      Railway.new(Railway, options)
    end

    class Railway < Activity
      def self.config
        Path.config.merge(
          builder_class:   Magnetic::Builder::Railway,
          default_outputs: Magnetic::Builder::Path.default_outputs,
          extend:          [
            DSL::Linear.def_dsl(:step, Magnetic::Builder::Railway, :StepPolarizations),
            DSL::Linear.def_dsl(:fail, Magnetic::Builder::Railway, :FailPolarizations),
            DSL::Linear.def_dsl(:pass, Magnetic::Builder::Railway, :PassPolarizations),
            DSL::Linear.def_dsl(:_end, Magnetic::Builder::Path,    :EndEventPolarizations), # TODO: TEST ME
          ],
        )
      end

      module DSL
        Linear = Activity::DSL::Linear # FIXME

        module_function

        def normalizer
          step_options(Trailblazer::Activity::Path::DSL.normalizer)
        end

        def normalizer_for_fail
          sequence = normalizer

          id = "railway.magnetic_to.fail"
          task = Fail.method(:merge_magnetic_to)

          sequence = Linear::DSL.insert_task(task, sequence: sequence,
                magnetic_to: :success, id: id, outputs: Path::DSL.unary_outputs, connections: Path::DSL.unary_connections,
                sequence_insert: [Linear::Insert.method(:Prepend), "End.success"])

          id = "railway.connections.fail.success_to_failure"
          task = Fail.method(:connect_success_to_failure)

          sequence = Linear::DSL.insert_task(task, sequence: sequence,
                magnetic_to: :success, id: id, outputs: Path::DSL.unary_outputs, connections: Path::DSL.unary_connections,
                sequence_insert: [Linear::Insert.method(:Replace), "path.connections"])
        end

        module Fail
          module_function

          def merge_magnetic_to((ctx, flow_options), *)
            ctx = ctx.merge(magnetic_to: :failure)

            return Right, [ctx, flow_options]
          end

          def connect_success_to_failure((ctx, flow_options), *)
            ctx = {connections: {success: [Linear::Search.method(:Forward), :failure]}}.merge(ctx)

            return Right, [ctx, flow_options]
          end
        end


        def step_options(sequence)
          Path::DSL.prepend_to_path( # this doesn't particularly put the steps after the Path steps.
            sequence,

            "railway.outputs"     => method(:reverse_merge_path_outputs),
            "railway.connections" => method(:reverse_merge_path_connections),
          )
        end

        def reverse_merge_path_outputs((ctx, flow_options), *)
          outputs = failure_outputs.merge(ctx[:outputs])
          ctx     = ctx.merge(outputs: outputs)

          return Right, [ctx, flow_options]
        end

        def reverse_merge_path_connections((ctx, flow_options), *)
          connections = failure_connections.merge(ctx[:connections])
          ctx         = ctx.merge(connections: connections)

          return Right, [ctx, flow_options]
        end

        def failure_outputs
          {failure: Activity::Output(Activity::Right, :failure)}
        end
        def failure_connections
          {failure: [Linear::Search.method(:Forward), :failure]}
        end

        Right = Trailblazer::Activity::Right

        def initial_sequence
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Path::DSL.initial_sequence
          sequence = Path::DSL.append_end(Activity::End.new(semantic: :failure), sequence, magnetic_to: :failure, id: "End.failure")
        end
      end # DSL
    end
  end
end
