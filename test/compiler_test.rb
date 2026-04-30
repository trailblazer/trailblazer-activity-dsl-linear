require "test_helper"

def a(x=1)
end

# This is a unit test that helps understanding how {Compiler} and {Sequence} work.
class CompilerTest < Minitest::Spec
  R = Trailblazer::Activity::Right
  L = Trailblazer::Activity::Left
  DSL = Trailblazer::Activity::DSL
  Act = Trailblazer::Activity

  let(:id_node_pairs) do
    lib_interface   = Trailblazer::Circuit::Task::Adapter::LibInterface
    my_exec_context = T.def_tasks(:a, :b, :c, :d)

    {
      a: Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), lib_interface],
      b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), lib_interface],
      c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), lib_interface],
      d: Trailblazer::Circuit::Node[:d, my_exec_context.method(:d), lib_interface],
      failure: Trailblazer::Circuit::Node[:"End.failure", Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), lib_interface],
      success: Trailblazer::Circuit::Node[:"End.success", Trailblazer::Activity::Terminus::Success.new(semantic: :success), lib_interface],
    }
  end
  let(:sequence) { Trailblazer::Activity::DSL::Sequence }

  it "set emtpy outputs when {terminus: true}" do
    seq = [
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:a],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
          },
        data: {id: :a},
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:b],
        wirings: # those get discarded.
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
          },
        data: {
          id: :b,
          terminus: true, # we want {b} to be a terminus.
          semantic: :success
        },
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:c],
        wirings:
          {
          },
        data: {id: :c},
      ),
    ]

    # TODO: make this somewhere else.
    my_sequence = Trailblazer::Activity::DSL::Sequence.new()
    my_sequence = seq.inject(my_sequence) do |sequence, row|
      Trailblazer::Circuit::Adds.(
        sequence,
        [row.data[:id], row, :after] # FIXME: this can be done much simpler.
      )
    end

    my_activity_schema = DSL::Sequence::Compiler.(my_sequence)
    # pp my_activity
    circuit = my_activity_schema[:circuit]

    assert_run circuit, seq: [:a, :b], terminus: R
  end

  it "simple linear approach where a {Sequence} is compiled into an {Activity}" do
    seq = [
      sequence::Row.new(
        magnetic_to: :success, # MinusPole
        # [Search::Forward(:success), Search::ById(:a)]
        node: id_node_pairs[:a],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new(L, :failure) => sequence::Search::Forward.new(:failure),
          },
        data: {id: :a},
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:b],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new("B/failure", :failure) => sequence::Search::Forward.new(:failure)
          },
        data: {id: :b},
      ),
      sequence::Row.new(
        magnetic_to: :failure,
        node: id_node_pairs[:c],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:failure),
            Act::Output.new(L, :failure) => sequence::Search::Forward.new(:failure)
          },
        data: {id: :c},
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:d],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new("D/failure", :failure) => sequence::Search::Forward.new(:failure)
          },
        data: {id: :d},
      ),
      sequence::Row.new(
        magnetic_to: :failure,
        node: id_node_pairs[:failure],
        wirings: {},
        data: {id: :"End.failure", terminus: true, semantic: :failure},
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:success],
        wirings: {},
        data: {id: :"End.success", terminus: true, semantic: :success},
      ),
    ]

    my_sequence = Trailblazer::Activity::DSL::Sequence.new()
    my_sequence = seq.inject(my_sequence) do |sequence, row|
      Trailblazer::Circuit::Adds.(
        sequence,
        [row.data[:id], row, :after] # FIXME: this can be done much simpler.
      )
    end


    my_activity_schema = DSL::Sequence::Compiler.(my_sequence)
    circuit = my_activity_schema[:circuit]
    my_activity = circuit # FIXME

    # pp my_activity

    assert_run my_activity, seq: [:a, :b, :d], terminus: id_node_pairs[:success].task
    assert_run my_activity, seq: [:a, :c], terminus: id_node_pairs[:failure].task,
      application_ctx: {a: Trailblazer::Activity::Left}
    assert_run my_activity, seq: [:a, :c], terminus: id_node_pairs[:failure].task,
      application_ctx: {a: Trailblazer::Activity::Left, c: Trailblazer::Activity::Left}
    assert_run my_activity, seq: [:a, :b, :c], terminus: id_node_pairs[:failure].task,
      application_ctx: {b: "B/failure"}
    assert_run my_activity, seq: [:a, :b, :d], terminus: id_node_pairs[:failure].task,
      application_ctx: {d: "D/failure"}

    assert_equal my_activity_schema.to_h[:outputs], {
      failure: Trailblazer::Activity::Output.new(id_node_pairs[:failure].task, :failure),
      success: Trailblazer::Activity::Output.new(id_node_pairs[:success].task, :success),
    }

# TODO: maybe test the rendered circuit, too?
  end
end
