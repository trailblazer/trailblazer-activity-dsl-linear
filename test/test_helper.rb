$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer/activity/dsl/linear"

require "minitest/autorun"

require "trailblazer/developer"
require "trailblazer/developer/render/circuit"
require "trailblazer/developer/render/linear"

require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  Implementing = T.def_steps(:a, :b, :c, :d, :e, :f, :g)

  # def assert_equal(asserted, expected)
  #   super(expected, asserted)
  # end

  # @param :seq String What the {:seq} variable in the result ctx looks like.
  def assert_call(activity, terminus: :success, seq: "[]", **ctx_variables)
    # Call without taskWrap!
    signal, (ctx, _) = activity.([{seq: [], **ctx_variables}, _flow_options = {}])

    assert_equal signal.to_h[:semantic], terminus, "assert_call expected #{terminus} terminus, not #{signal}. Use assert_call(activity, terminus: #{signal.to_h[:semantic]})"
    assert_equal ctx.inspect, {seq: "%%%"}.merge(ctx_variables).inspect.sub('"%%%"', seq)
  end

  # TODO: use everywhere!!!
  def assert_activity(activity, *args)
    assert_process_for(activity, *args)
  end

  def assert_sequence(sequence, *args)
    assert_process_for Activity::DSL::Linear::Compiler.(sequence), *args
  end

  def compile_process(sequence)
    _process = Linear::Compiler.(sequence)
  end

  Linear = Trailblazer::Activity::DSL::Linear

  def assert_process(seq, *args)
    process = compile_process(seq)

    assert_process_for(process, *args)
  end

  Activity = Trailblazer::Activity

  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d, :f, :g)
    end
    implementing::Start = Activity::Start.new(semantic: :default)
    implementing::Failure = Activity::End(:failure)
    implementing::Success = Activity::End(:success)

    implementing
  end

  include Trailblazer::Activity::Testing::Assertions

    # taskWrap tester :)
  def add_1(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end
  def add_2(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 2
    return wrap_ctx, original_args # yay to mutable state. not.
  end
end

module Fixtures
  module_function

  def circuit_interface_builder(step)
    CircuitInterface.new(step)
  end

  class CircuitInterface
    def initialize(step)
      @step = step
    end

    def call((ctx, flow_options), *)
      @step.(ctx)

      return Activity::Right, [ctx, flow_options]
    end

    def inspect
      %{#<Fixtures::CircuitInterface:0x @step=#{Trailblazer::Activity::Testing.render_task(@step)}>}
    end
  end
end
