require "test_helper"
require "benchmark/ips"

class FGdfgsdVariableMappingRuntimeTest < Minitest::Spec
  it "what" do

    class A
      def self.call((ctx, _), **o)
        ctx[:a] = "a"
      end
    end

    class B
      def self.call(ctx, _, **)
        ctx[:a] = "a"
      end
    end

    Benchmark.ips do |x|
      x.report("traditional, composed signature") {
        A.call([{}, {}], runner: Object)
      }

      x.report("positional") do
        B.call({}, {}, runner: Object)
      end

      x.compare!
    end
  end
end

# Comparison:
#           positional:  4148105.9 i/s
# traditional, composed signature:  3598373.4 i/s - 1.15x  (± 0.00) slower


class SignatureBenchmark < Minitest::Spec
  class Bla
    def self.mixed(ctx, flow_options, **circuit_options)
      ctx[:seq] << 1
    end

    def self.positional(ctx, flow_options, circuit_options)
      ctx[:seq] << 1
    end

    def self.positional_wildcard(ctx, *)
      ctx[:seq] << 1
    end

    # as oppossed to the "mixed" signature, we always have the **ctx keywords without any additional work.
    # this is, in Ruby 3.4.1, 1.5x slower if you actually access kwargs.
    # if you don't use kwargs and simply ignore them using **) (see #positional_wildcard_kwargs_wildcard),
    # this is only 1.24x slower!
    # if not passing a **ctx, this is 1.21x slower.
    def self.positional_wildcard_kwargs(ctx, *, seq:, **)
      seq << 1
    end

    def self.positional_wildcard_kwargs_wildcard(ctx, *, **)
      ctx[:seq] << 1
    end

    def self.positional_explicit_and_kwargs(ctx, flow_options, circuit_options, seq:, **)
      seq << 1
    end

    def self.positional_translating_to_step_interface(ctx, flow_options, circuit_options)
      filter_with_step_interface(ctx, **ctx)
    end
    def self.filter_with_step_interface(ctx, seq:, **)
      seq << 1
    end
  end

  it "comparing different signature concepts" do
    Benchmark.ips do |x|
      x.report("mixed") {
        Bla.mixed({seq: []}, {}, runner: Object)
      }

      x.report("positional") do
        Bla.positional({seq: []}, {}, {runner: Object})
      end

      x.report("positional_wildcard") do
        Bla.positional_wildcard({seq: []}, {}, {runner: Object})
      end

      x.report("positional_wildcard kwargs") do
        Bla.positional_wildcard_kwargs(ctx={seq: []}, {}, {runner: Object}, **ctx)
      end

      x.report("positional two wildcards") do
        Bla.positional_wildcard_kwargs_wildcard(ctx={seq: []}, {}, {runner: Object}, **ctx)
      end

      # no wildcard
      x.report("positional all args explicit and with kwargs") do
        Bla.positional_explicit_and_kwargs(ctx={seq: []}, {}, {runner: Object}, **ctx)
      end

      x.report("positional two wildcards, omitting **ctx") do
        Bla.positional_wildcard_kwargs_wildcard(ctx={seq: []}, {}, {runner: Object})
      end

      x.report("positional translating to step interface") do
        Bla.positional_translating_to_step_interface({seq: []}, {}, {runner: Object})
      end

      x.compare!

# Comparison:
#           positional:  3011101.7 i/s
#                mixed:  2628040.6 i/s - 1.15x  (± 0.00) slower
#  positional_wildcard:  2546450.1 i/s - 1.18x  (± 0.00) slower
# positional two wildcards, omitting **ctx:  2467748.2 i/s - 1.22x  (± 0.00) slower
# positional two wildcards:  2412093.2 i/s - 1.25x  (± 0.00) slower
# positional translating to step interface:  2187172.0 i/s - 1.38x  (± 0.00) slower
# positional_wildcard kwargs:  1986416.5 i/s - 1.52x  (± 0.00) slower


    end
  end

  it "comparing Pipeline that directly calls task vs. with runner" do
    module Blaa
      def self.pipeline_call_with_direct_task_call(sequence, ctx, flow_options, circuit_options)
        sequence.each do |task, call_options|
          ctx, flow_options = task.(ctx, flow_options, call_options)
        end

        return ctx, flow_options, circuit_options
      end

      def self.pipeline_calls_activity(sequence, ctx, flow_options, circuit_options)
        sequence.each do |activity|
          ctx, flow_options = activity.(ctx, flow_options, circuit_options)
        end

        return ctx, flow_options, circuit_options
      end

      Task = ->(ctx, flow_options, circuit_options) { ctx[:seq] << 1; [ctx, flow_options] }

      # def self.my_runner(task, ctx, flow_options, circuit_options)

      # end

      # def self.pipeline_call_with_runner(sequence, ctx, flow_options, circuit_options)
      #   sequence.each do |task|
      #     ctx, flow_options = my_runner(task, ctx, flow_options, circuit_options)
      #   end
      # end
    end

    sequence_with_call_options = (1..30).collect do |i|
      [Blaa::Task, {bla: 1}]
    end

    class MyActivity
      MyCallOptions = {bla: 1}

      def self.call(ctx, flow_options, circuit_options)
        Blaa::Task.(ctx, flow_options, MyCallOptions)
      end
    end

    sequence_with_activity = (1..30).collect do |i|
      MyActivity
    end

    ctx, _ = Blaa.pipeline_call_with_direct_task_call(sequence_with_call_options, {seq: []}, {}, {})
    puts "@@@@@ #{ctx.inspect}"

    ctx, _ = Blaa.pipeline_calls_activity(sequence_with_activity, {seq: []}, {}, {})
    puts "@@@@@ #{ctx.inspect}"

    Benchmark.ips do |x|
      x.report("direct") {
        Blaa.pipeline_call_with_direct_task_call(sequence_with_call_options, {seq: []}, {}, {})
      }

      x.report("activity") {
        Blaa.pipeline_calls_activity(sequence_with_activity, {seq: []}, {}, {})
      }

      x.compare!

# Learning: indirection via Activity.call isn't much slower.

# Comparison:
#               direct:   192105.2 i/s
#             activity:   177651.9 i/s - 1.08x  (± 0.00) slower

    end
  end
end
