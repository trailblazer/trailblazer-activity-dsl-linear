module Trailblazer
  class Activity
    module DSL
      class Normalizer
        def self.call(normalizers, name, method_name, **options)
          normalizer_pipe = normalizers[name]

          lib_ctx, _ = Circuit::Processor.(normalizer_pipe, {user_options: method_name, **options}, {}, nil, runner: Trailblazer::Circuit::Node::Runner)

          return lib_ctx[:id], lib_ctx[:sequence_row]
        end

      end
    end
  end
end
