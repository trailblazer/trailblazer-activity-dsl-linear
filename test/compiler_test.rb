require "test_helper"

def a(x=1)
end

# This is a unit test that helps understanding how {Compiler} and {Sequence} work.
class CompilerTest < Minitest::Spec
  R = Trailblazer::Activity::Right
  L = Trailblazer::Activity::Left
  DSL = Trailblazer::Activity::DSL # FIXME: remove!
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

  def build_sequence(seq_rows)
    # TODO: make this somewhere else.
    my_sequence = Trailblazer::Activity::DSL::Sequence.new()
    my_sequence = seq_rows.inject(my_sequence) do |sequence, row|
      Trailblazer::Circuit::Adds.(
        sequence,
        [row.data[:id], row, :after] # FIXME: this can be done much simpler.
      )
    end
  end

  # DISCUSS: we need :outputs and we need :wirings, the later connecting {signal => search}. However, we reuse the Output instances in wirings so we can extract the semantic for terminus outputs.

  it "we got Search::Nil that will point to nil, indicating to Circuit that this is a terminus output" do
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
      sequence::Row.new( # this row represents a terminus as we know it from TRB 2.1, with a dedicated task.
        magnetic_to: :success,
        node: id_node_pairs[:b],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Nil.new, # will result in {Right => nil}
          },
        data: {
          id: :b,
          # terminus: true, # we want {b} to be a terminus.
          # semantic: :success
        },
      ),
      sequence::Row.new( # we're adding this just to make sure that :b doesn't connect to any descendent.
        magnetic_to: :success,
        node: id_node_pairs[:c],
        wirings:
          {
          },
        data: {id: :c},
      ),
    ]

    my_sequence = build_sequence(seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    circuit = my_activity.to_h[:circuit]

    assert_run circuit, seq: [:a, :b], terminus: R

    assert_equal my_activity.to_h[:outputs], {
      success: Trailblazer::Activity::Output.new(R, :success),
    }
  end

  it "a sequence_row can have multiple outputs, and some of them can be termini, some can be a connector" do
    seq = [
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:a],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new(L, :failure) => sequence::Search::Nil.new,
          },
        data: {id: :a},
      ),
      sequence::Row.new( # this row represents a terminus as we know it from TRB 2.1, with a dedicated task.
        magnetic_to: :success,
        node: id_node_pairs[:b],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Nil.new, # will result in {Right => nil}
          },
        data: {id: :b},
      ),
    ]

    my_sequence = build_sequence(seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    circuit = my_activity.to_h[:circuit]

    assert_run circuit, seq: [:a, :b], terminus: R
    assert_run circuit, seq: [:a], terminus: L, target_ctx: {seq: [], a: L}

    assert_equal my_activity.to_h[:outputs], {
      failure: Trailblazer::Activity::Output.new(L, :failure),
      success: Trailblazer::Activity::Output.new(R, :success),
    }
  end

  it "empty wiring simply doesn't connect the node" do
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
      sequence::Row.new( # we're adding this just to make sure that :b doesn't connect to any descendent.
        magnetic_to: :success,
        node: id_node_pairs[:c],
        wirings:
          {
          },
        data: {id: :c},
      ),
      sequence::Row.new( # this row represents a terminus as we know it from TRB 2.1, with a dedicated task.
        magnetic_to: :success,
        node: id_node_pairs[:b],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Nil.new, # will result in {Right => nil}
          },
        data: {id: :b},
      ),
    ]

    my_sequence = build_sequence(seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    circuit = my_activity.to_h[:circuit]

    assert_raises KeyError do
      assert_run circuit, seq: [:a, :c]#, terminus: R
    end

    assert_equal circuit.flow_map, {:a=>{Trailblazer::Activity::Right=>[:c, Trailblazer::Activity::Right]}, :c=>{}, :b=>{Trailblazer::Activity::Right=>[nil, Trailblazer::Activity::Right]}}

    assert_equal my_activity.to_h[:outputs], {
      success: Trailblazer::Activity::Output.new(R, :success),
    }
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
        wirings: {
          Act::Output.new(id_node_pairs[:failure].task, :failure) => sequence::Search::Nil.new
        },
        data: {id: :"End.failure"},
      ),
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:success],
        wirings: {
          Act::Output.new(id_node_pairs[:success].task, :success) => sequence::Search::Nil.new
        },
        data: {id: :"End.success"},
      ),
    ]

    my_sequence = Trailblazer::Activity::DSL::Sequence.new()
    my_sequence = seq.inject(my_sequence) do |sequence, row|
      Trailblazer::Circuit::Adds.(
        sequence,
        [row.data[:id], row, :after] # FIXME: this can be done much simpler.
      )
    end


    my_activity = DSL::Sequence::Compiler.(my_sequence)

    assert_run my_activity.to_h[:circuit], seq: [:a, :b, :d], terminus: id_node_pairs[:success].task
    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: id_node_pairs[:failure].task,
      target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_activity.to_h[:circuit], seq: [:a, :c], terminus: id_node_pairs[:failure].task,
      target_ctx: {seq: [], a: Trailblazer::Activity::Left, c: Trailblazer::Activity::Left}
    assert_run my_activity.to_h[:circuit], seq: [:a, :b, :c], terminus: id_node_pairs[:failure].task,
      target_ctx: {seq: [], b: "B/failure"}
    assert_run my_activity.to_h[:circuit], seq: [:a, :b, :d], terminus: id_node_pairs[:failure].task,
      target_ctx: {seq: [], d: "D/failure"}


    assert_equal my_activity.to_h[:outputs], {
      failure: Trailblazer::Activity::Output.new(id_node_pairs[:failure].task, :failure),
      success: Trailblazer::Activity::Output.new(id_node_pairs[:success].task, :success),
    }

# TODO: maybe test the rendered circuit, too?
  end

  # TODO: explicitely test ById

  it "Search::ById where {:a} points to an yet existing {:b}" do
    my_seq = [
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:a],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new(L, :failure) => sequence::Search::ById.new(:b),
          },
        data: {id: :a},
      ),

      sequence::Row.new(
        magnetic_to: nil,
        node: id_node_pairs[:b],
        wirings:
          {
            Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
          },
        data: {id: :b},
      ),

      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:success],
        wirings: {
          Act::Output.new(id_node_pairs[:success].task, :success) => sequence::Search::Nil.new
        },
        data: {id: :"End.success"},
      ),
    ]

    my_sequence = build_sequence(my_seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    assert_equal my_activity.to_h[:outputs], {
      # failure: Trailblazer::Activity::Output.new(id_node_pairs[:failure].task, :failure),
      success: Trailblazer::Activity::Output.new(id_node_pairs[:success].task, :success),
    }

    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: id_node_pairs[:success].task
    assert_run my_activity.to_h[:circuit], seq: [:a, :b], terminus: id_node_pairs[:success].task, target_ctx: {seq: [], a: L}
  end

  it "Forward() can't find its target" do
    my_seq = [
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:a],
        wirings:
          {
            # Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new(R, :failure) => sequence::Search::Forward.new(:unknown),
          },
        data: {id: :a},
      ),
    ]

    my_sequence = build_sequence(my_seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    assert_equal my_activity.to_h[:circuit].to_h[:flow_map].to_h, {:a => {R => [DSL::Sequence::Search::TargetNotFound, R]}}

    # FIXME: we don't get an exception here, yet.
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: R
  end

  it "Id() can't find its target" do
    my_seq = [
      sequence::Row.new(
        magnetic_to: :success,
        node: id_node_pairs[:a],
        wirings:
          {
            # Act::Output.new(R, :success) => sequence::Search::Forward.new(:success),
            Act::Output.new(R, :failure) => sequence::Search::ById.new(:unknown),
          },
        data: {id: :a},
      ),
    ]

    my_sequence = build_sequence(my_seq)
    my_activity = DSL::Sequence::Compiler.(my_sequence)

    assert_equal my_activity.to_h[:circuit].to_h[:flow_map].to_h, {:a => {R => [DSL::Sequence::Search::TargetNotFound, R]}}

    # FIXME: we don't get an exception here, yet.
    assert_run my_activity.to_h[:circuit], seq: [:a], terminus: R
  end

  it "End() or :adds" do

  end
end
