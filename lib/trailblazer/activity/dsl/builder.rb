module Trailblazer
  class Activity # DISCUSS: the Activity class is defined in the activity gem and already got some {setting} directives.

    # module Compile # NOTE: this code is unrelated to DSL and *how* the sequence was built.
    #   def self.compile_activity!(config)
    #     activity = DSL::Sequence::Compiler.(config.sequence)

    #     config.activity = activity
    #   end
    # end

    module DSL
      class Builder < Struct.new(:normalizers, :sequence, :default_options, keyword_init: true) # DISCUSS: do we want the {activity} here?
        def initialize(sequence: Sequence.new, default_options: {}, **)
          super
        end

        # @public
        def call(&block)
          call!(&block)
        end

        def call!(&block)
          instance_exec(&block) # this calls #step --> #step!.

          # self.activity = Compile.compile_activity!(config) # DISCUSS: omit this when we're in zeitwerk env.
          # Compile.compile_activity!(config) # DISCUSS: omit this when we're in zeitwerk env.
# pp sequence.nodes.collect { |id, row| [id, row.magnetic_to, row.wirings] }
          activity = Sequence::Compiler.(sequence)

          return activity, sequence
        end

        # NOTE: we only update sequence here, compiling is the job of the caller.
        def step!(user_provider = nil, **options) # TODO: make generic
          self.sequence =
            DSL.add_to_sequence(self.sequence, self.normalizers,

              user_provider,
              exec_context: self, # DISCUSS: where do we need this?
              **self.default_options, # these are settings such as {magnetic_to:}, settable per builder.
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
