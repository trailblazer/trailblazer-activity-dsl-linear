require "trailblazer-activity"
require "trailblazer/declarative"

class Trailblazer::Activity
  module DSL
    # Implementing a specific DSL, simplified version of the {Magnetic DSL} from 2017.
    #
    # Produces {Implementation} and {Intermediate}.
    module Linear
      # TODO: remove this deprecation for 1.1.
      module Insert
        def self.method(name)
          warn "[Trailblazer] Using `Trailblazer::Activity::DSL::Linear::Insert.method(:#{name})` is deprecated.
  Please use `Trailblazer::Activity::Adds::Insert.method(:#{name})`."

          Trailblazer::Activity::Adds::Insert.method(name)
        end
      end

      module Deprecate
        # Used in combination with `Activity::Deprecate.warn`. Guesses the location
        # of the method call from the stacktrace.
        def self.dsl_caller_location
          caller_index = caller_locations.find_index { |location| location.to_s =~ /recompile_activity_for/ }
          caller_index ? caller_locations[caller_index+2] : caller_locations[0]
        end
      end
    end # Linear
  end
end

require "trailblazer/activity/dsl/linear/sequence"
require "trailblazer/activity/dsl/linear/sequence/builder"
require "trailblazer/activity/dsl/linear/sequence/search"
require "trailblazer/activity/dsl/linear/sequence/compiler"
require "trailblazer/activity/dsl/linear/normalizer/inherit" # DISCUSS. should we add normalizer/options/... or something?
require "trailblazer/activity/dsl/linear/normalizer/extensions"
require "trailblazer/activity/dsl/linear/normalizer"
require "trailblazer/activity/dsl/linear/normalizer/terminus"
require "trailblazer/activity/dsl/linear/helper"
require "trailblazer/activity/dsl/linear/helper/path"
require "trailblazer/activity/dsl/linear/strategy"
require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"
require "trailblazer/activity/dsl/linear/feature/variable_mapping"
require "trailblazer/activity/dsl/linear/feature/variable_mapping/dsl"
require "trailblazer/activity/dsl/linear/feature/variable_mapping/runtime"
require "trailblazer/activity/dsl/linear/feature/patch"

# feature/variable_mapping
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::Path, :step)
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::Railway, :step, :pass, :fail)
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::FastTrack, :step, :pass, :fail)
