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
        setting :circuit
        setting :outputs
        setting :helper_forwarder # Where we delegate Subprocess(, Output() etc.

        extend DSL # {#forward_to_builder!}
        extend DSL::Step # #step

        def self.to_h
          {
            circuit: config.circuit,
            outputs: config.outputs # TODO: test me.
          }
        end
# FIXME: test this behavior (Runtime module_.
        def self.start_tuple # FIXME: make this nicer, for Processor
          config.circuit.start_tuple
        end
        def self.resolve(*args) # FIXME: make this nicer, for Processor
          config.circuit.resolve(*args)
        end

        def self.inherited(subclass)
          super

          subclass.config.builder = config.builder.clone(defaults: {exec_context: subclass.new.freeze})
        end

        config.builder = Builder.new(default_options: {})

        # DISCUSS: keep this here? We use it as a target in helper_forwarder.
        def self.helper_forwarder_target
          config.builder
        end

        def self.build(builder:, default_options:, helpers: false, adds:, &block)
          helper_modules = nil # FIXME: extract to separate method.
          helper_forwarder = Module.new

          if helpers
            helper_modules = helpers.keys
            helper_functions = helpers.values.flatten.uniq

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

          circuit, outputs, _ = builder.(&block) if block_given?

          return circuit, outputs, builder, helper_forwarder
        end
      end
    end # DSL
  end
end

