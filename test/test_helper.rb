$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"


require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing
