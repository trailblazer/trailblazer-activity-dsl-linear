require "test_helper"

class VariableMappingRuntimeTest < Minitest::Spec
  let(:vm) { Trailblazer::Activity::DSL::Linear::VariableMapping }

  it "what" do

    # In() => ->(*) { snippet }
    a = vm::SetVariable.new(
      name: "In/a",
      write_name: :a,
      filter: ->(*) { "value for a" },
      user_filter: nil
    )

    wrap_ctx, _ = a.({aggregate: {}}, nil)

    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:a=>\"value for a\"}})

    # In() => :b
    # VariableFromCtx.new(variable_name: read_name),
    b = vm::SetVariable.new(
      name: "In/b",
      write_name: :b,
      filter: vm::VariableFromCtx.new(variable_name: :b),
      user_filter: nil
    )

    wrap_ctx, _ = b.({aggregate: {}}, [[{b: "b"}, {}], {}])

    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:b=>"b"}})

    # Inject(:c) => ->(*) { "default for c" }
    user_filter = ->(*) { "default for c" }

    c = vm::SetVariable::Default.new(
      name: "Inject/c/default",
      write_name: :c,
      filter:         vm::VariableFromCtx.new(variable_name: :c),
      user_filter: nil,
      default_filter: Trailblazer::Activity::Circuit.Step(user_filter, option: false),
      condition: vm::VariablePresent.new(variable_name: :c)
    )

    wrap_ctx, _ = c.({aggregate: {}}, [[{b: "b"}, {}], {}])

    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:c=>"default for c"}})
  end

  class MergeVariables < Trailblazer::Activity::Railway
    step :call_filter
    step :wrap_value_with_hash
    step :merge_variables_into_aggregate

    module Methods
      module_function
      def call_filter(ctx, filter:, original_args:, **)
        # circuit_options = original_args[1]

        variable = filter.(*original_args) # circuit-step interface

        ctx[:value] = variable
      end

      def wrap_value_with_hash(ctx, value:, write_name:, **)
        ctx[:value] = {write_name => value}
      end

      def merge_variables_into_aggregate(ctx, aggregate:, value:, **)
        ctx[:aggregate] = merge_variables(value, aggregate)
      end

      private def merge_variables(variables, aggregate, receiver = aggregate)
        aggregate = receiver.merge(variables)
      end
    end
    include Methods
  end

  it "with activity" do

    ctx = {
      aggregate: {},
      original_args: [[{a: "a"}, {}], {}],
      filter: ->(*) { "value for a" },
      write_name: :a
    }

    # Don't call it with {TaskWrap.invoke} as we don't need/want this logic here (performance)!
    signal, (ctx, _) = MergeVariables.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:a=>"value for a"})
  end

  it "benchmark" do
    a_filter = vm::SetVariable.new(
      name: "In/a",
      write_name: :a,
      filter: ->(*) { "value for a" },
      user_filter: nil
    )

    ctx = {
      aggregate: {},
      original_args: [[{a: "a"}, {}], {}],
      filter: ->(*) { "value for a" },
      write_name: :a
    }

    class_methods_activity = Class.new(Trailblazer::Activity::Railway) do
      step task: MergeVariables::Methods.method(:call_filter)
      step task: MergeVariables::Methods.method(:wrap_value_with_hash)
      step task: MergeVariables::Methods.method(:merge_variables_into_aggregate)
    end

    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("object-based") {
        wrap_ctx, _ = a_filter.({aggregate: {}}, nil)
      }

      exec_context = MergeVariables.new
      activity = MergeVariables.to_h[:activity] # 1 sec faster

      # x.report("activity") do
      #   ctx[:aggregate] = {}
      #   signal, (ctx, _) = activity.([ctx, {}], exec_context: exec_context)
      # end


      activity = class_methods_activity.to_h[:activity] # 1 sec faster
      # pp activity.to_h
      # raise
      circuit = activity.to_h[:circuit]

      # mini runner in combo with not-wrapped tasks: "only" 6.6 slower
      # activity/class method:   196404.6 i/s - 6.64x  (± 0.00) slower
      circuit_runner = ->(task, (ctx, _), **) { task.(ctx, **ctx); [Trailblazer::Activity::Right, [ctx, _]] }

      my_circuit_options = {runner: circuit_runner, start_task: MergeVariables::Methods.method(:call_filter)} # activity/class method:   212795.2 i/s - 6.22x  (± 0.00) slower


      x.report("activity/class method") do
        ctx[:aggregate] = {}
        signal, (ctx, _) = circuit.([ctx, {}], **my_circuit_options)
      end

      x.compare!
    end
  end

  it "compare ruby vs pipeline-like approach" do
    module A
      module_function

      def a(arg)
        arg = b(arg)
        arg = c(arg)
        arg = d(arg)
      end

      def b(arg)
        arg << :b
        arg
      end

      def c(arg)
        arg << :c
        arg
      end

      def d(arg)
        arg << :d
        arg
      end
    end

    class Filter
      include A

      def call(arg)
        a(arg)
      end
    end

    pp Filter.new.call([:a])

    pipe = [
      # A.method(:a),
      A.method(:b),
      A.method(:c),
      A.method(:d),
    ]

    def run_pipe_with_each(pipe, arg)
      pipe.each do |step|
        arg = step.(arg)
      end
      arg
    end

    pp run_pipe_with_each(pipe, [:a])

    def run_pipe_with_loop(pipe, arg)
      i = 0
      task = pipe[i]

      loop do
        arg = task.(arg)
        task = pipe[i += 1] or return arg
      end
    end

    pp run_pipe_with_loop(pipe, [:a])

    Runner = ->(task, arg) { task.(arg) }
    def run_with_loop_and_runner(pipe, arg, runner: Runner)
      i = 0
      task = pipe[i]

      loop do
        arg = runner.(task, arg)
        task = pipe[i += 1] or return arg
      end
    end

    pp run_with_loop_and_runner(pipe, [:a])
     # raise

    @termini = {nil => true, 1 => true}
    def run_with_loop_and_runner_and_terminus(pipe, arg, runner: Runner)
      i = 0
      task = pipe[i]

      loop do
        arg = runner.(task, arg)
        task = pipe[i += 1]


        # return arg if [1, nil].include?(task) # TWICE as slow!
        return arg if @termini.key?(task)
      end

      arg
    end

    pp run_with_loop_and_runner_and_terminus(pipe, [:a])
     # raise

    class A_as_Activity < Trailblazer::Activity::Railway
      def self.b(ctx, arg:, **)
      # def self.b(ctx, arg)
        arg << :b
      end
      def self.c(ctx, arg:, **)
      # def self.c(ctx, arg)
        arg << :c
      end
      def self.d(ctx, arg:, **)
      # def self.d(ctx, arg)
        arg << :d
      end
      step task: method(:b)
      step task: method(:c)
      step task: method(:d)
    end

    metal_circuit = A_as_Activity.to_h[:activity].to_h[:circuit]

    metal_circuit.instance_variable_set(:@termini, [A_as_Activity.method(:d)]) # (2.) removing execution of Success: 13.5 --> 11.01x  improvement.

    # def my_circuit_runner(task, (ctx, _), **)
    #   task.(ctx, **ctx)
    #   [Trailblazer::Activity::Right, [ctx, _]]
    # end

    class MyCircuitRunner
      def self.call(task, (ctx, _), **)
        task.(ctx, **ctx)
        # task.(ctx, ctx[:arg]) # (4.) no kwargs: 10.8 --> 8.70x

        return Trailblazer::Activity::Right, [ctx, _]
      end
    end

    # @circuit_runner = method(:my_circuit_runner)
    # @circuit_runner = ->(task, (ctx, _), **) { task.(ctx, **ctx); [Trailblazer::Activity::Right, [ctx, _]] }
    # @circuit_runner = ->(task, (ctx, _), **) { task.(ctx, ctx[:arg]); [Trailblazer::Activity::Right, [ctx, _]] }
    # @circuit_runner = MyCircuitRunner.new
    @circuit_runner = MyCircuitRunner # {3.} providing non-proc as runner: 11.0 --> 10.80x

    def run_circuit(circuit, ctx)
      circuit.([ctx, {}], runner: @circuit_runner, start_task: A_as_Activity.method(:b)) # (1.) providing start_task: 14.8 --> 13.5 improvement.
    end

    pp run_circuit(metal_circuit, {arg: []})

    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("object-based") {
        Filter.new.call([:a])
      }

      # x.report("pipe") do
      #   run_pipe_with_each(pipe, [:a])
      # end

      # x.report("pipe with loop") do
      #   run_pipe_with_loop(pipe, [:a])
      # end

      # x.report("pipe with loop and runner") do
      #   run_with_loop_and_runner(pipe, [:a])
      # end

#       Comparison:
#         object-based:  3206311.6 i/s
#       pipe with loop:  1706401.2 i/s - 1.88x  (± 0.00) slower
# pipe with loop and runner:  1426149.1 i/s - 2.25x  (± 0.00) slower
# pipe with loop and runner and terminus:   690864.0 i/s - 4.64x  (± 0.00) slower

      x.report("pipe with loop and runner and terminus") do
        run_with_loop_and_runner_and_terminus(pipe, [:a])
      end

      # normal circuit:  circuit:   236406.1 i/s - 13.62x  (± 0.00) slower

      x.report("circuit") do
        run_circuit(metal_circuit, {arg: [:a]})
      end

      x.compare!
# Comparison:
#         object-based:  4686151.9 i/s
#                 pipe:  3287775.1 i/s - 1.43x  (± 0.00) slower

    end
  end
end
