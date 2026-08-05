module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.

    # module Compile # NOTE: this code is unrelated to DSL and *how* the sequence was built.
    #   def self.compile_activity!(config)
    #     activity = DSL::Sequence::Compiler.(config.sequence)

    #     config.activity = activity
    #   end
    # end

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
          self.sequence =
            DSL.add_to_sequence(self.sequence, self.normalizers[:step],

              user_provider,
              exec_context: self, # DISCUSS: where do we need this?
              **self.default_options[:step], # these are settings such as {magnetic_to:}, settable per builder.
              **options
            ) # TODO: add {type: :step}
        end

        # TODO: generate from configuration
        def step(*args, **options, &block)
          step!(*args, **options, &block)
        end
      end
    end
  end
end
