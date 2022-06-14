class Trailblazer::Activity
  module DSL
    module Linear
      # A {Sequence} consists of rows, each row represents one step (or task) of an activity
      # and its incoming and outgoing connections.
      # {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
      # A Sequence is compiled into an activity using {Compiler}.
      #
      # Complies with the Adds interface (#to_a).
      class Sequence < Array
        # Row interface is part of the ADDs specification.
        class Row < Array
          def id
            self[3][:id]
          end
        end

        # Return {Sequence row} consisting of {[magnetic_to, task, connections_searches, data]}.
        def self.create_row(task:, magnetic_to:, wirings:, **options)
          Row[
            magnetic_to,
            task,
            wirings,
            options # {id: "Start.success"}
          ]
        end
      end # Sequence
    end # Linear
  end
end
