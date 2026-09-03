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
        def step!(type, user_provider = nil, **options, &block)
          options = options.merge(block_arg: block) if block_given?

          self.sequence = alter_sequence(
            self.sequence,
            self.normalizers.fetch(type),

            user_provider,
            **self.default_options.fetch(type), # these are settings such as {magnetic_to:}, settable per builder.
            **options
          )
        end

        # TODO: generate from configuration
        def step(*args, **options, &block)
          step!(:step, *args, **options, &block)
        end

        def left(*args, **options, &block)
          step!(:left, *args, **options, &block)
        end

        def pass(*args, **options, &block)
          step!(:pass, *args, **options, &block)
        end

        # @private
        def alter_sequence(sequence, normalizers, user_provider, **options)
          adds_for_sequence = Normalizer.(normalizers, :step, user_provider,
            **options,
            sequence: sequence # TODO: explicitely test that we pass {:sequence}.
          )

          sequence = Circuit::Adds.(
            sequence,
            *adds_for_sequence
          )
        end

        # DISCUSS: this should be the only interface to alter a Builder.
        def clone(merge:, adds: nil)
          builder = super()

          builder.default_options = builder.default_options.collect { |k,v| [k, v.merge(merge)] }.to_h

          if adds
            builder.normalizers = update_normalizers(builder.normalizers, adds: adds)
          end

          return builder
        end

        # @private
        def update_normalizers(normalizers, adds:)
          normalizers.collect do |name, circuit|
            circuit = Circuit::Adds.(circuit, *adds)

            [name, circuit]
          end
          .to_h
          .freeze
        end
      end
    end
  end
end
