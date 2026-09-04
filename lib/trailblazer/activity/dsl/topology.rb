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
        setting :helper_forwarder # Where we delegate Subprocess(, Output() etc.

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

        config.builder = Builder.new(default_options: {}) # FIXME: use Topology()

        require "trailblazer/activity/dsl/topology/helper" # FIXME: remove.
        # extend Helper # import {Subprocess()} and friends as class methods. creates shortcuts to {Output()} etc.
        include Helper::Constants

        # DISCUSS: keep this here? We use it as a target in helper_forwarder.
        def self.helper_forwarder_target
          config.builder
        end
      end






      # TODO: this logic is build, not creating a Topology!
      def self.Topology(builder:, normalizers:, default_options:, helpers: false, adds:, &block)
        helper_modules = nil # FIXME: extract to separate method.

        helper_forwarder = Module.new

        if helpers
          helper_modules = helpers.keys
          helper_functions = helpers.values.flatten.uniq

          # FIXME: where do we do this?
          require "forwardable"
          helper_forwarder = Module.new do
            extend Forwardable
            def_delegators :helper_forwarder_target, *helper_functions
          end
        end

        builder = builder.clone(
          defaults: default_options,
          # default_options: default_options,
          adds: adds,
          helpers: helper_modules
        )

        activity, _ = builder.(&block) if block_given?

        return activity, builder, helper_forwarder
      end
    end # DSL
  end
end

