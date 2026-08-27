require "trailblazer/activity"
require "dry/configurable"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      def forward_to_builder!(normalizer_name, user_provider = nil, **options) # FIXME: separate module!
        activity, _sequence = config.builder.() { send(normalizer_name, user_provider, **options) }

        self.config.activity = activity
      end

      module Step
        def step(*args, **options)
          forward_to_builder!(:step, *args, **options)
        end
      end # Step

      module Left
        def left(*args, **options)
          forward_to_builder!(:left, *args, **options)
        end

        alias fail left
      end

      module Pass
        def pass(*args, **options)
          forward_to_builder!(:pass, *args, **options)
        end
      end

      def self.id_for_terminus(semantic:, **)
        :"End.#{semantic}" # TODO: use everywhere
      end

      def self.options_for_terminus_step(semantic:, terminus_class: Terminus::Success)
        {
          task:        terminus = terminus_class.new(semantic: semantic),
          wirings:     wirings_for_terminus(signal: terminus, semantic: semantic),
          id:          DSL.id_for_terminus(semantic: semantic),
          magnetic_to: semantic,
          adds_insertion_args: [:after]
        }
      end

      def self.wirings_for_terminus(signal:, semantic:)
        {
          Output.new(signal, semantic) => DSL::Sequence::Search::Nil.new
        }
      end

      RIGHT_LEFT_OUTPUTS = {
        success: Output.new(Activity::Right, :success),
        failure: Output.new(Activity::Left, :failure),
      }
    end # DSL
  end
end

require "trailblazer/activity/dsl/sequence"
require "trailblazer/activity/dsl/sequence/search"
require "trailblazer/activity/dsl/sequence/compiler"

require "trailblazer/activity/dsl/builder"

require "trailblazer/activity/dsl/topology"
require "trailblazer/activity/dsl/normalizer"
require "trailblazer/activity/dsl/normalizer/step"
# Trailblazer::Activity::DSL::Topology.config.normalizer = {
#   step: Trailblazer::Activity::DSL::Normalizer::Step
# }

require "trailblazer/activity/dsl/feature/output_tuples"
require "trailblazer/activity/dsl/feature/output_tuples/helper"
require "trailblazer/activity/dsl/feature/output_tuples/normalizer"
Trailblazer::Activity::DSL::Topology::Helper.include(Trailblazer::Activity::DSL::Feature::OutputTuples::Helper)

require "trailblazer/activity/dsl/feature/terminus"

require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"

require "trailblazer/activity/dsl/feature/subprocess"
Trailblazer::Activity::DSL::Topology::Helper.include(Trailblazer::Activity::DSL::Feature::Subprocess::Helper)

require "trailblazer/activity/dsl/feature/patch"
