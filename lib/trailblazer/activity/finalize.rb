module Trailblazer
  class Activity
    module Finalize
      # TODO: currently, we have to override this step method in order to NOT compile every time.
      def step(user_provider = nil, **options) # FIXME: separate module!
        config.sequence = DSL.add_to_sequence(config.sequence, config.normalizer, user_provider, **options)
      end

      def finalize
        Compile.compile_activity!(config)
      end
    end
  end
end
