class Trailblazer::Activity
  module DSL
    module Linear
      # A {Sequence} consists of rows, each row represents one step (or task) of an activity
      # and its incoming and outgoing connections.
      # {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
      # A Sequence is compiled into an activity using {Compiler}.
      #
      # Complies with the Adds interface (#to_a).
      class Sequence
        # Row interface is part of the ADDs specification.
        class Row < Struct.new(:magnetic_to, :task, :wirings, :data, :task_wrap)
          # Part of ADDS compliancy, see {activity} gem {adds.rb}.
          def id
            data[:id]
          end

          def to_a
            [magnetic_to, task, wirings, data, task_wrap]
          end
        end

        # Return {Sequence row} consisting of {[magnetic_to, task, connections_searches, data, ...]}.
        # Each row is process by {Sequence::Compiler}.
        def self.Row(task:, magnetic_to:, wirings:, task_wrap:, data:)
          Row.new(
            magnetic_to,
            task,
            wirings,
            data, # {id: "Start.success"}
            task_wrap
          )
        end
      end # Sequence
    end # Linear
  end
end
