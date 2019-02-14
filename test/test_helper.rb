$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"
require "trailblazer/activity/dsl/linear"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"


require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing

Minitest::Spec.class_eval do
  def Cct(activity)
    cct = Trailblazer::Developer::Render::Circuit.(activity)
  end

  def compile_process(sequence)
    process = Linear::Compiler.(sequence)
  end

  Linear = Trailblazer::Activity::DSL::Linear

  def assert_process(seq, semantic, circuit)
    process = compile_process(seq)

    process.to_h[:outputs].inspect.must_equal %{[#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=#{semantic.inspect}>, semantic=#{semantic.inspect}>]}

    cct = Cct(process: process)
    cct.must_equal %{#{circuit}}
  end
end
