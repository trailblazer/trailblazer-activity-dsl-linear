module Trailblazer
  class Activity
    module DSL
      module Feature
        module OutputTuples

          # Left side objects.
          module Output
            # Note that both {Semantic} and {CustomOutput} are {is_a?(Output)}
            Semantic     = Struct.new(:semantic, :generic?).include(Output)
            CustomSignal = Struct.new(:semantic, :signal, :generic?).include(Output) # generic? is always false
          end

          # Right side objects.
          module Target
            # Connector when using Track(:success).
            class Track < Struct.new(:color, :adds, :options)
              def call(*)
                search_strategy = options[:wrap_around] ? Sequence::Search::WrapAround : Sequence::Search::Forward

                return search_strategy.new(color), adds
              end
            end
          end
        end
      end
    end
  end
end
