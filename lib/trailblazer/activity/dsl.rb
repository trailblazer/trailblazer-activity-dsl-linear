require "trailblazer/activity"
require "dry/configurable"

module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      def forward_to_builder!(normalizer_name, user_provider = nil, **options, &block) # FIXME: separate module!
        activity, _sequence = config.builder.() { send(normalizer_name, user_provider, **options, &block) }

        self.config.activity = activity
      end

      module Step
        def step(*args, **options, &block)
          forward_to_builder!(:step, *args, **options, &block)
        end
      end # Step

      module Left
        def left(*args, **options, &block)
          forward_to_builder!(:left, *args, **options, &block)
        end

        alias fail left
      end

      module Pass
        def pass(*args, **options, &block)
          forward_to_builder!(:pass, *args, **options, &block)
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
require "trailblazer/activity/dsl/topology/configure"
require "trailblazer/activity/dsl/normalizer"
require "trailblazer/activity/dsl/normalizer/step"

require "trailblazer/activity/dsl/feature/output_tuples"
require "trailblazer/activity/dsl/feature/output_tuples/helper"
require "trailblazer/activity/dsl/feature/output_tuples/normalizer"

require "trailblazer/activity/dsl/feature/terminus"
require "trailblazer/activity/dsl/feature/inherit" # DISCUSS: needs to be loaded before Path, currently.
require "trailblazer/activity/dsl/feature/data"

require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"

require "trailblazer/activity/dsl/feature/patch"
require "trailblazer/activity/dsl/feature/subprocess"

require "trailblazer/activity/dsl/feature/path"

require "trailblazer/activity/dsl/feature/extension/task_wrap"
require "trailblazer/activity/dsl/feature/extension/options"

[Trailblazer::Activity::Path, Trailblazer::Activity::Railway, Trailblazer::Activity::FastTrack].each do |topology|
  activity, builder, helper_forwarder = Trailblazer::Activity::DSL.Topology(
    builder: topology.config.builder, default_options: {},

    helpers: {
      Trailblazer::Activity::DSL::Feature::Subprocess::Helper => [:Subprocess], # no :adds.
      Trailblazer::Activity::DSL::Feature::Path::Helper => [:Path], # no :adds.
    },
    adds: [
      # add the {inherit: true} feature:
      [
        :record_options, Trailblazer::Activity::DSL::Feature::Inherit::Normalizer::Node::Record,
        :after, :build_task_wrap_pipeline
      ],
      [
        :replay_options, Trailblazer::Activity::DSL::Feature::Inherit::Normalizer::Node::Replay,
        :after, :build_task_wrap_pipeline
      ],

      # add the {Data.Variable} feature:
      [
        :compile_data, Trailblazer::Activity::DSL::Feature::Data::Normalizer::Node,
        :before, :build_sequence_row
      ],

    ],
  )

  topology.config.builder = builder
  topology.extend helper_forwarder
end
