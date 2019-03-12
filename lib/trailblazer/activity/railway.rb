module Trailblazer
  # Implementation module that can be passed to `Activity[]`.
  class Activity
    class Railway
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

          sequence = Linear::DSL.insert_task(sequence,
            task: task,
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Prepend), "path.wirings"])

          id = "railway.connections.fail.success_to_failure"
          task = Fail.method(:connect_success_to_failure)

          sequence = Linear::DSL.insert_task(sequence,
            task: task,
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Replace), "path.connections"])
        end

        def normalizer_for_pass
          sequence = normalizer

          id = "railway.connections.pass.failure_to_success"
          task = Pass.method(:connect_failure_to_success)

          sequence = Linear::DSL.insert_task(sequence,
            task: task,
            magnetic_to: :success, id: id,
            wirings: [Linear::Search.Forward(Path::DSL.unary_outputs[:success], :success)],
            sequence_insert: [Linear::Insert.method(:Append), "path.connections"])
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

        module Pass
          module_function

          def connect_failure_to_success((ctx, flow_options), *)
            connections = ctx[:connections].merge({failure: [Linear::Search.method(:Forward), :success]})

            return Right, [ctx.merge(connections: connections), flow_options]
          end
        end

        # Add {Railway} steps to normalizer path.
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

        def initial_sequence(failure_end:, **path_options)
          # TODO: this could be an Activity itself but maybe a bit too much for now.
          sequence = Path::DSL.initial_sequence(path_options)
          sequence = Path::DSL.append_end(sequence, task: failure_end, magnetic_to: :failure, id: "End.failure")
        end

        class State < Linear::State
          def step(task, options={}, &block)
            options = @normalizer.(:step, normalizer_options: @normalizer_options, options: task, user_options: options)

            @sequence = Linear::DSL.apply_adds_from_dsl(@sequence, options)
          end

          def fail(task, options={}, &block)
            options = @normalizer.(:fail, normalizer_options: @normalizer_options, options: task, user_options: options)

            @sequence = Linear::DSL.apply_adds_from_dsl(@sequence, options)
          end

          def pass(task, options={}, &block)
            options = @normalizer.(:pass, normalizer_options: @normalizer_options, options: task, user_options: options)

            @sequence = Linear::DSL.apply_adds_from_dsl(@sequence, options)
          end
        end # State

        Normalizers = Linear::State::Normalizer.new(
          step:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer ), # here, we extend the generic FastTrack::step_normalizer with the Activity-specific DSL
          fail:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_fail ),
          pass:  Linear::Normalizer.activity_normalizer( Railway::DSL.normalizer_for_pass ),
        )


        def self.OptionsForState(normalizers: Normalizers, track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success",
          failure_end: Activity::End.new(semantic: :failure),
          **options)

          initial_sequence = Railway::DSL.initial_sequence(track_name: track_name, end_task: end_task, end_id: end_id, failure_end: failure_end)

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

      class << self
        private def fail(*args, &block)
          args = forward_block(args, block)

          seq = @state.fail(*args)

          @process = Linear::Compiler.(seq)
        end

        private def pass(*args, &block)
          args = forward_block(args, block)

          seq = @state.pass(*args)

          @process = Linear::Compiler.(seq)
        end
      end

      extend Path::Strategy

      initialize!(DSL::State.new(DSL.OptionsForState()))

    end # Railway

    def self.Railway(options)
      Class.new(Railway) do
        initialize!(Railway::DSL::State.new(Railway::DSL.OptionsForState(options)))
      end
    end
  end
end
