module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    def self.Railway(options={})
      Railway.new(Railway, options)
    end

    class Railway < Activity
      module DSL
        Linear = Activity::DSL::Linear # FIXME

        module_function

        def normalizer
          step_options(Trailblazer::Activity::Path::DSL.normalizer)
        end

        # Change some parts of the "normal" {normalizer} pipeline.
        # TODO: make this easier, even at this step.

        def normalizer_for_fail
          sequence = normalizer

          id = "railway.magnetic_to.fail"
          task = Fail.method(:merge_magnetic_to)

          sequence = Linear::DSL.insert_task(sequence, task: task,
                magnetic_to: :success, id: id,
                wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
                sequence_insert: [Linear::Insert.method(:Prepend), "path.wirings"])

          id = "railway.connections.fail.success_to_failure"
          task = Fail.method(:connect_success_to_failure)

          sequence = Linear::DSL.insert_task(sequence, task: task,
                magnetic_to: :success, id: id,
                wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
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

            {
              "railway.outputs"     => method(:normalize_path_outputs),
              "railway.connections" => method(:normalize_path_connections),
            },

            Linear::Insert.method(:Prepend), "path.wirings" # override where it's added.
          )
        end

        def normalize_path_outputs((ctx, flow_options), *)
          outputs = failure_outputs.merge(ctx[:outputs])
          ctx     = ctx.merge(outputs: outputs)

          return Right, [ctx, flow_options]
        end

        def normalize_path_connections((ctx, flow_options), *)
          connections = failure_connections.merge(ctx[:connections])
          ctx         = ctx.merge(connections: connections)

          return Right, [ctx, flow_options]
        end

        def failure_outputs
          {failure: Activity::Output(Activity::Left, :failure)}
        end
        def failure_connections
          {failure: [Linear::Search.method(:Forward), :failure]}
        end

        Right = Trailblazer::Activity::Right

        def initial_sequence(options)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Path::DSL.initial_sequence(options)
          sequence = Path::DSL.append_end(sequence, task: Activity::End.new(semantic: :failure), magnetic_to: :failure, id: "End.failure")
        end

Linear = Activity::DSL::Linear

        class State < Linear::State
          def step(task, options={}, &block)
            options = @normalizer.(:step, normalizer_options: @normalizer_options, options: task, user_options: options)

            @sequence = Linear::DSL.apply_adds_from_dsl(@sequence, options)
          end

          def fail(task, options={}, &block)
            options = @normalizer.(:fail, normalizer_options: @normalizer_options, options: task, user_options: options)

            @sequence = Linear::DSL.apply_adds_from_dsl(@sequence, options)
          end
        end # State

        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          fail:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_fail ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
        )


        def self.OptionsForState(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success", **options)
          initial_sequence = Railway::DSL.initial_sequence(track_name: track_name, end_task: end_task, end_id: end_id)

          {
            normalizers: normalizers,
            initial_sequence: initial_sequence,

            track_name: track_name,
            end_id: end_id,
            step_interface_builder: Trailblazer::Activity::TaskBuilder.method(:Binary),
            adds: [], # FIXME: EH.
            **options
          }
        end

      end # DSL
    end
  end
end
