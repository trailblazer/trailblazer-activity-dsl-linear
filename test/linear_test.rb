require "test_helper"

#:intermediate
  def a(x=1)
  end
#:intermediate end

module Trailblazer::Activity::DSL
  # Implementing a specific DSL, simplified version of the {Magnetic DSL} from 2017.
  #
  # Produces {Implementation} and {Intermediate}.
  module Linear
    module Search
      module_function

      def Forward(output, target_color)
        ->(sequence, me) do
          target_seq_row = sequence[sequence.index(me)+1..-1].find { |seq_row| seq_row[0] == target_color }

          return output, target_seq_row
        end
      end

      def Noop(output)
        ->(sequence, me) do
          nil
        end
      end

      def ById(output, id)

      end
    end # Search

    module Compiler
      module_function

      # Default strategy to find out what's a stop event is to inspect the TaskRef's {data[:stop_event]}.
      def find_stop_task_refs(intermediate_wiring)
        intermediate_wiring.collect { |task_ref, outs| task_ref.data[:stop_event] ? task_ref : nil }.compact
      end

      # The first task in the wiring is the default start task.
      def find_start_task_refs(intermediate_wiring)
        [intermediate_wiring.first.first]
      end

      def call(sequence, find_stops: method(:find_stop_task_refs), find_start: method(:find_start_task_refs))
        _implementations, intermediate_wiring =
          sequence.inject([[], []]) do |(implementations, intermediates), seq_row|
            magnetic_to, task, connections, data = seq_row
            id = data[:id]

            # execute all {Search}s for one sequence row.
            connections = find_connections(seq_row, connections, sequence)

            implementations += [[id, Intermediate::Task(task, connections.collect { |output, _| output }) ]]

            intermediates += [[Intermediate::TaskRef(id, data), connections.collect { |output, target_id| Intermediate::Out(output.semantic, target_id) }] ]

            [implementations, intermediates]
          end

        start_task_refs = find_start.(intermediate_wiring)
        stop_task_refs = find_stops.(intermediate_wiring)

        intermediate   = Intermediate.new(Hash[intermediate_wiring], stop_task_refs, start_task_refs)
        implementation = Hash[_implementations]

        Intermediate.(intermediate, implementation)
      end

      # private

      def find_connections(seq_row, strategies, sequence)
        strategies.collect do |search|
          output, target_seq_row = search.(sequence, seq_row) # invoke the node's "connection search" strategy.
          next if output.nil? # FIXME.

          [
            output,                                     # implementation
            target_seq_row[3][:id],  # intermediate
            target_seq_row # DISCUSS: needed?
          ]
        end.compact
      end
    end # Compiler
  end

  class Intermediate < Struct.new(:wiring, :stop_task_refs, :start_tasks)

# FIXME: move those back to Activity::Structure
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)
    Process = Struct.new(:circuit, :outputs, :nodes)

    # Intermediate structures
    TaskRef = Struct.new(:id, :data) # TODO: rename to NodeRef
    # Outs = Class.new(Hash)
    Out  = Struct.new(:semantic, :target)

    def self.TaskRef(id, data={}); TaskRef.new(id, data) end
    def self.Out(*args);           Out.new(*args)        end
    def self.Task(*args);          Task.new(*args)       end


    # Implementation structures
    Task = Struct.new(:circuit_task, :outputs)

    def self.call(intermediate, implementation)
      circuit = circuit(intermediate, implementation)
      nodes   = node_attributes(implementation)
      outputs = outputs(intermediate.stop_task_refs, nodes)
      process = Process.new(circuit, outputs, nodes)
    end

    # From the intermediate "template" and the actual implementation, compile a {Circuit} instance.
    def self.circuit(intermediate, implementation)
      wiring = Hash[
        intermediate.wiring.collect do |task_ref, outs|
          task = implementation.fetch(task_ref.id)

          [
            task.circuit_task,
            Hash[ # compute the connections for {circuit_task}.
              outs.collect { |required_out|
                [
                  for_semantic(task.outputs, required_out.semantic).signal,
                  implementation.fetch(required_out.target).circuit_task
                ]
              }
            ]
          ]
        end
      ]

      Trailblazer::Circuit.new(
        wiring,
        intermediate.stop_task_refs.collect { |task_ref| implementation.fetch(task_ref.id).circuit_task },
        start_task: intermediate.start_tasks.collect { |task_ref| implementation.fetch(task_ref.id).circuit_task }[0]
      )
    end

    # DISCUSS: this is intermediate-independent?
    def self.node_attributes(implementation, nodes_data={}) # TODO: process {nodes_data}
      implementation.collect do |id, task| # id, Task{circuit_task, outputs}
        NodeAttributes.new(id, task.outputs, task.circuit_task, {})
      end
    end

    # intermediate/implementation independent.
    def self.outputs(stop_task_refs, nodes_attributes)
      stop_task_refs.collect do |task_ref|
        # Grab the {outputs} of the stop nodes.
        nodes_attributes.find { |node_attrs| task_ref.id == node_attrs.id }.outputs
      end.flatten(1)
    end

    private

    # Apply to any array.
    def self.for_semantic(ary, semantic)
      ary.find { |out| out.semantic == semantic } or raise "`#{semantic}` not found"
    end
  end
end

class LinearTest < Minitest::Spec
  Right = Class.new#Trailblazer::Activity::Right
  Left = Class.new#Trailblazer::Activity::Right
  PassFast = Class.new#Trailblazer::Activity::Right

  Inter = Trailblazer::Activity::DSL::Intermediate
  Activity = Trailblazer::Activity

  Linear = Trailblazer::Activity::DSL::Linear

  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d)
    end
    implementing::Start = Activity::Start.new(semantic: :default)
    implementing::Failure = Activity::End(:failure)
    implementing::Success = Activity::End(:success)

    implementing
  end

  it do
    # generated by the editor or a specific DSL.
    # DISCUSS: is this considered DSL-independent code?
    # TODO: unique {id}
    # Intermediate shall not contain actual object references, since it might be generated.
    intermediate = Inter.new({
        Inter::TaskRef(:a) => [Inter::Out(:success, :b), Inter::Out(:failure, :c)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :d), Inter::Out(:failure, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, "End.failure"), Inter::Out(:failure, "End.failure")],
        Inter::TaskRef(:d) => [Inter::Out(:success, "End.success"), Inter::Out(:failure, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [],
        Inter::TaskRef("End.failure", stop_event: true) => [],
      },
      [Inter::TaskRef("End.success"), Inter::TaskRef("End.failure")],
      [Inter::TaskRef(:a)] # start
    )

    implementation = {
      :a => Inter::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Inter::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Inter::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Inter::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Inter::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Inter::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }

    circuit = Inter.circuit(intermediate, implementation)
    pp circuit

    nodes = Inter.node_attributes(implementation)
    # generic NodeAttributes
    pp nodes

    outputs = Inter.outputs(intermediate.stop_task_refs, nodes)
    pp outputs

    process = Inter::Process.new(circuit, outputs, nodes)

    puts cct = Trailblazer::Developer::Render::Circuit.(process: process)

    cct.must_equal %{
#<Method: #<Module:0x>.a>
 {LinearTest::Right} => #<Method: #<Module:0x>.b>
 {LinearTest::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {LinearTest::Right} => #<End/:failure>
 {LinearTest::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {LinearTest::Left} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "simple linear approach where a {Sequence} is compiled into an Intermediate/Implementation" do
    seq = [
      [
        nil,
        implementing::Start,
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
        ],
        {id: "Start.default"},
      ],
      [
        :success, # MinusPole
        # [Search::Forward(:success), Search::ById(:a)]
        implementing.method(:a),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          ),
        ],
        {id: :a},
      ],
      [
        :success,
        implementing.method(:b),
        [
          Linear::Search::Forward(
            Activity::Output("B/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output("B/failure", :failure),
            :failure
          )
        ],
        {id: :b},
      ],
      [
        :failure,
        implementing.method(:c),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :failure
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
         )
        ],
        {id: :c},
      ],
      [
        :success,
        implementing.method(:d),
        [
          Linear::Search::Forward(
            Activity::Output("D/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          )
        ],
        {id: :d},
      ],
      [
        :success,
        implementing::Success,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Success, :success)
          )
        ],
        {id: "End.success", stop_event: true},
      ],
      [
        :failure,
        implementing::Failure,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Failure, :failure)
          )
        ],
        {id: "End.failure", stop_event: true},
      ],
    ]

    process = Linear::Compiler.(seq)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)

    cct.must_equal %{
#<Start/:default>
 {LinearTest::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {LinearTest::Right} => #<Method: #<Module:0x>.b>
 {LinearTest::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {LinearTest::Right} => #<End/:failure>
 {LinearTest::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {LinearTest::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

  end
end
