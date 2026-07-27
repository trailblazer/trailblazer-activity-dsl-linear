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

            # Connector when using Id(:validate).
            class Id < Struct.new(:value)
              def call(*)
                return Sequence::Search::ById.new(value), [] # {value} is the "target".
              end
            end


            # Connector representing a (to-be-created?) terminus when using End(:semantic).
            class Terminus < Struct.new(:semantic)
              def call(ctx)
                sequence = ctx[:sequence]

                end_id     = DSL.id_for_terminus(semantic: semantic)
                id_for_terminus_task_wrap = :"task_wrap.#{end_id}" # TODO: implement that in Activity.

                end_exists = sequence.find { |id, row| id == id_for_terminus_task_wrap }

                adds = []

                unless end_exists
                  new_terminus = Activity::Terminus.new(semantic)

                  adds = [
                    [
                      Circuit::Node[id_for_terminus_task_wrap, new_terminus, Circuit::Task::Adapter::LibInterface],
                    ]
                  ]
                end

                return Sequence::Search::ById.new(id_for_terminus_task_wrap), [adds]
              end
            end
          end
        end
      end
    end
  end
end
