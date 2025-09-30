require "test_helper"
require "benchmark/ips"

class VariableMappingRuntimeTest < Minitest::Spec
  let(:vm) { Trailblazer::Activity::DSL::Linear::VariableMapping }

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
        arg = b(arg: arg)
        arg = c(arg: arg)
        arg = d(arg: arg)
      end

      def b(arg:, **)
        arg << :b
        arg
      end

      def c(arg:, **)
        arg << :c
        arg
      end

      def d(arg:, **)
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
        arg = step.(arg: arg)
      end
      arg
    end

    pp run_pipe_with_each(pipe, [:a])

    def run_pipe_with_loop(pipe, arg)
      i = 0
      task = pipe[i]

      loop do
        arg = task.(arg: arg)
        task = pipe[i += 1] or return arg
      end
    end

    pp run_pipe_with_loop(pipe, [:a])

    Runner = ->(task, arg) { task.(arg: arg) }
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

    class A_as_Activity < Trailblazer::Activity::Path # (6.) Path or Railway doesn't matter, same performance.
      def self.b(ctx, arg:, **)
      # def self.b(ctx, arg)
        arg << :b
      end
      B_method = method(:b) # always has to be the same instance.

      def self.c(ctx, arg:, **)
      # def self.c(ctx, arg)
        arg << :c
      end
      def self.d(ctx, arg:, **)
      # def self.d(ctx, arg)
        arg << :d
      end
      step task: B_method
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

    # (5.) making reference Object-only implementation use kwargs, too (for fairness!): 6.60 slower.

    # @circuit_runner = method(:my_circuit_runner)
    # @circuit_runner = ->(task, (ctx, _), **) { task.(ctx, **ctx); [Trailblazer::Activity::Right, [ctx, _]] }
    # @circuit_runner = ->(task, (ctx, _), **) { task.(ctx, ctx[:arg]); [Trailblazer::Activity::Right, [ctx, _]] }
    # @circuit_runner = MyCircuitRunner.new
    @circuit_runner = MyCircuitRunner # {3.} providing non-proc as runner: 11.0 --> 10.80x

    def run_circuit(circuit, ctx)
      circuit.([ctx, {}], runner: @circuit_runner, start_task: A_as_Activity::B_method) # (1.) providing start_task: 14.8 --> 13.5 improvement.
    end
    # (7.) using task.object_id for lookups: 6.6 => 5.3x

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

  it "include? vs key?" do
    termini = [Trailblazer::Activity::End.new(semantic: :success), Trailblazer::Activity::End.new(semantic: :failure)]
    termini_hash = termini.collect { |terminus| [terminus, true] }.to_h

    Benchmark.ips do |x|
      x.report("include?") {
        termini.include?(Trailblazer::Activity::Right)
      }

      x.report("key?") {
        termini_hash.key?(Trailblazer::Activity::Right)
      }

      x.compare!
    end
  end

  it "Object-key vs. :symbol key" do
    proc1 = ->(*) { 1 }
    proc2 = ->(*) { 2 }
    proc3 = ->(*) { 3 }
    proc4 = ->(*) { 4 }

    h1 = {
      proc1 => 1,
      proc2 => 2,
      proc3 => 3,
      proc4 => 4,
    }

    h3 = {
      proc1.object_id => 1,
      proc2.object_id => 2,
      proc3.object_id => 3,
      proc4.object_id => 4,
    }

    h2 = {
      :one => 1,
      :two => 2,
      :three => 3,
      :four => 4
    }

    h4 = {
      Object => 1,
      Trailblazer::Activity::Right => 2,
      Trailblazer::Activity::Left => 3,
      Class => 4
    }

    object1 = Object.new
    object2 = Object.new
    object3 = Object.new
    object4 = Object.new

    h5 = {
      object1 => 1,
      object2 => 2,
      object3 => 3,
      object4 => 4
    }

    def a; 1; end
    def b; 2; end
    def c; 3; end
    def d; 4; end

    h6 = {
      method(:a) => 1,
      method(:b) => 2,
      method(:c) => 3,
      method(:d) => 4
    }

# Comparison:
#              :symbol: 23249987.3 i/s
#            object_id: 16012076.1 i/s - 1.45x  (± 0.00) slower
#            instances: 12630027.6 i/s - 1.84x  (± 0.00) slower
#            constants: 12384440.1 i/s - 1.88x  (± 0.00) slower
#                procs:  4977475.3 i/s - 4.67x  (± 0.00) slower
#     method instances:  4144551.9 i/s - 5.61x  (± 0.00) slower

# => procs as key are super slow, methods too

    Benchmark.ips do |x|
      x.report("procs") {
        h1[proc3]
      }

      x.report("object_id") {
        h3[proc3.object_id]
      }

      x.report(":symbol") {
        h2[:three]
      }

      x.report("constants") {
        h4[Trailblazer::Activity::Left]
      }

      x.report("instances") {
        h5[object3]
      }

      method_a = method(:a)
      x.report("method instances") {
        h6[method_a]
      }

      x.compare!
    end
  end
end
