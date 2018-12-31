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
end
