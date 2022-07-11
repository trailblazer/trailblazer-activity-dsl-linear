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
    end # Linear
  end
end

require "trailblazer/activity/dsl/linear/sequence"
require "trailblazer/activity/dsl/linear/sequence/builder"
require "trailblazer/activity/dsl/linear/sequence/search"
require "trailblazer/activity/dsl/linear/sequence/compiler"
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
require "trailblazer/activity/dsl/linear/feature/patch"

# feature/variable_mapping
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::Path, :step)
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::Railway, :step, :pass, :fail)
Trailblazer::Activity::DSL::Linear::VariableMapping.extend!(Trailblazer::Activity::FastTrack, :step, :pass, :fail)
