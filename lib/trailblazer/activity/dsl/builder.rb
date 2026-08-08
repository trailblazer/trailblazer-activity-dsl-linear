module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.

    module DSL
      # The point of Builder is: encapsulating how to produce a Sequence from a DSL block.
      # DISCUSS: not sure if it should always produce an Activity, though, or run the Compiler.
      #
      # we currently store the sequence and the default_options for the normalizers in this instance,
      # which then can be deleted once we're finalized.
      class Builder < Struct.new(:normalizers, :sequence, :default_options, keyword_init: true) # DISCUSS: do we want the {activity} here?
        def initialize(sequence: Sequence.new, **)
          super
        end

        # @public
        def call(&block)
          self.sequence = update_sequence!(&block)

          activity = compile_activity

          return activity, self.sequence
        end

        # #update_sequence!
        def update_sequence!(&block)
          instance_exec(&block) # this calls #step --> #step!.

          # pp sequence.nodes.collect { |id, row| [id, row.magnetic_to, row.wirings] }
          sequence
        end

        def compile_activity
          _activity = Sequence::Compiler.(sequence)
        end

        # NOTE: we only update sequence here, compiling is the job of the caller.
        def step!(user_provider = nil, **options) # TODO: make generic
          self.sequence = alter_sequence(
            self.sequence,
            self.normalizers[:step],

            user_provider,
            **self.default_options[:step], # these are settings such as {magnetic_to:}, settable per builder.
            **options
          ) # TODO: add {type: :step}
        end

        # TODO: generate from configuration
        def step(*args, **options, &block)
          step!(*args, **options, &block)
        end

        # @private
        def alter_sequence(sequence, normalizers, user_provider, **options)
          # here, we can inject an :exec_context that keeps configuration.
          adds_for_sequence = Normalizer.(normalizers, :step, user_provider,
            **options,
            sequence: sequence # TODO: explicitely test that we pass {:sequence}.
          )

          sequence = Circuit::Adds.(
            sequence,
            *adds_for_sequence
          )
        end
      end
    end
  end
end
