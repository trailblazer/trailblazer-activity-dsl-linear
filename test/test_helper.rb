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

  # TODO: use everywhere!!!
  def assert_activity(activity, *args)
    assert_process_for(activity, *args)
  end

  def assert_sequence(sequence, *args)
    assert_process_for Activity::DSL::Linear::Compiler.(sequence), *args
  end

  def compile_process(sequence)
    _process = Trailblazer::Activity::DSL::Linear::Compiler.(sequence)
  end

  def assert_process(seq, *args)
    process = compile_process(seq)

    assert_process_for(process, *args)
  end

  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d, :f, :g)
    end
    implementing::Start = Trailblazer::Activity::Start.new(semantic: :default)
    implementing::Failure = Trailblazer::Activity::End(:failure)
    implementing::Success = Trailblazer::Activity::End(:success)

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

      return Trailblazer::Activity::Right, [ctx, flow_options]
    end

    def inspect
      %{#<Fixtures::CircuitInterface:0x @step=#{Trailblazer::Activity::Testing.render_task(@step)}>}
    end
  end
end
