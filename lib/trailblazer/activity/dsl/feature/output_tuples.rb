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
              def call(**)
                search_strategy = options[:wrap_around] ? Sequence::Search::WrapAround : Sequence::Search::Forward

                return search_strategy.new(color), adds
              end
            end

            # Connector when using Id(:validate).
            class Id < Struct.new(:value)
              def call(**)
                return Sequence::Search::ById.new(value), [] # {value} is the "target".
              end
            end


            # Connector representing a (to-be-created?) terminus when using End(:semantic).
            class Terminus < Struct.new(:semantic)
              def call(sequence:, adds: [], **ctx) # DISCUSS: should we allow :adds from outside?
                end_id     = DSL.id_for_terminus(semantic: semantic)
                end_exists = sequence.to_a.find { |id, row| id == end_id }

                unless end_exists
                  new_terminus = Activity::Terminus.new(semantic: semantic)

                  row_for_sequence = Sequence::Row.new(
                    magnetic_to: semantic,
                    node: Circuit::Node[new_terminus, Circuit::Task::Adapter::LibInterface],
                    wirings: {Activity::Output.new(new_terminus, semantic) => Sequence::Search::Nil.new}, # DISCUSS: redundant with #options_for_mock_terminus.
                    data: {id: end_id},
                  )

                  adds = [
                    [
                      end_id,
                      row_for_sequence,
                      :after
                    ]
                  ]
                end

                return Sequence::Search::ById.new(end_id), adds
              end
            end
          end
        end
      end
    end
  end
end
