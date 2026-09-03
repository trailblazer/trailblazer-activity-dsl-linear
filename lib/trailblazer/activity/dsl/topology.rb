module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.
    module DSL
      # Class-based DSL to define a circuit (and an activity).
      # NOTE: This is not meant for light-weight library circuits as needed in Reform or Representable,
      #       but for end-user facing business components.
      # NOTE: This used to be named Strategy.
      class Topology
        extend Dry::Configurable

        setting :builder # this keeps the Sequence instance.
        setting :activity

        extend DSL # {#forward_to_builder!}
        extend DSL::Step # #step

        def self.to_h
          {
            circuit: config.activity.circuit,
            outputs: config.activity.outputs # TODO: test me.
          }
        end
# FIXME: test this behavior (Runtime module_.
        def self.start_tuple # FIXME: make this nicer, for Processor
          config.activity.circuit.start_tuple
        end
        def self.resolve(*args) # FIXME: make this nicer, for Processor
          config.activity.circuit.resolve(*args)
        end

        def self.inherited(subclass)
          super

          subclass.config.builder = config.builder.clone(defaults: {exec_context: subclass.new.freeze})
        end

        config.builder = Builder.new(default_options: {})

        require "trailblazer/activity/dsl/topology/helper"
        extend Helper # import {Subprocess()} and friends as class methods. creates shortcuts to {Output()} etc.
        include Helper::Constants
      end
    end # DSL
  end
end

