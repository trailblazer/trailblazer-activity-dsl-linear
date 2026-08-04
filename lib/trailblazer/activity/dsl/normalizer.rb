module Trailblazer
  class Activity
    module DSL
      class Normalizer
        def self.call(normalizer, name, first_arg, **options)
          lib_ctx, _ = Circuit::Processor.(normalizer, options.merge(first_arg: first_arg), {}, nil, runner: Trailblazer::Circuit::Node::Runner)

          return lib_ctx[:adds_for_sequence]
        end
      end
    end
  end
end
