module Trailblazer
  class Activity
    module DSL
      class Topology
        module Configure
          module_function

          # NOTE: this *changes* internal state of a Topology.
          def call!(topology, helpers: nil, **options_for_clone)
            if helpers
              topology.extend(*helpers)
            end

            # this is a fully immutable operation, copy and extend the builder instance.
            topology.config.builder = topology.config.builder.clone(**options_for_clone) # accepts {:adds} and {:defaults}.

            return topology
          end
        end # Configure
      end
    end
  end
end
