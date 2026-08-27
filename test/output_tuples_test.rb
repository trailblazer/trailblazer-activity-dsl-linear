require "test_helper"

class OutputTuplesTest < Minitest::Spec
  let(:my_exec_context) { T.def_steps(:a) }

  MyExecContext = T.def_steps(:a) # TODO: use method(:a) instead of :a and remove {:exec_context} option, not part of this test!
  MyFailure = Trailblazer::Activity::Terminus::Success.new(semantic: :failure)
  # MyHelper = Trailblazer::Activity::DSL::Feature::OutputTuples::Helper

  def self.my_options_for_builder
    normalizer_for_step = Trailblazer::Activity::DSL::Normalizer::Step

    extended_normalizer_for_step = Trailblazer::Circuit::Adds.(
      normalizer_for_step,
      [
        :normalize_wirings, Trailblazer::Activity::DSL::Feature::OutputTuples::Normalizer::Node,
        :before, :build_sequence_row
      ],
    )

    normalizers = {
      # step: Trailblazer::Activity::DSL::Normalizer::Step
      step: extended_normalizer_for_step,
    }

    {
      normalizers: normalizers,
        # sequence: Trailblazer::Activity::DSL::Sequence.new
      default_options: {
        step: {}
      }
    }
  end

  it "doesn't override existing {:wirings} because feature is skipped" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      step :a,
        # magnetic_to: :success,
        exec_context: MyExecContext,
        # adds_insertion_args: [:before, :success],
        wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success)}
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
      # flow_options: {application_ctx: {seq: [], a: "a success signal", success: "success signal"}}
  end

  it "without a specific layout normalizer, we can pass any tuples and get the appropriate {:wirings} for it" do
    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)

      step :a,
        exec_context: MyExecContext,
        Output(:failure) => Track(:success), # failure becomes success.
        Output(:success) => Track(:failure),
        outputs: {
          # the concrete signals here will be used for the wirings.
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
        # this generates something like
        # wirings: {Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success) => Trailblazer::Activity::DSL::Sequence::Search::Forward.new(:success)}
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
  end

  it "only one output" do

  end

  it "output with custom signal" do
    my_exec_context = T.def_tasks(:a)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)

      step task: my_exec_context.method(:a), id: :a,
        Output(:failure) => Track(:failure),
        Output(:success, signal: Object) => Track(:success),
        outputs: {
          # the concrete signals here will be used for the wirings.
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Object}
    assert_raises KeyError do
      assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Right}
    end
  end

  it "three outputs, no third {:outputs} provided" do
    my_exec_context = T.def_tasks(:a)
    my_finished = Trailblazer::Activity::Terminus::Success.new(semantic: :finished)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)
      step **MyTest.options_for_mock_terminus(task: my_finished, semantic: :finished)

      step task: my_exec_context.method(:a), id: :a,
        Output(:failure) => Track(:failure),
        Output(:success) => Track(:success),
        Output(:finished, signal: Object) => Track(:finished),
        outputs: {
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: my_finished, target_ctx: {seq: [], a: Object}
  end

  it "three outputs, {:outputs} provided" do
    my_exec_context = T.def_tasks(:a)
    my_finished = Trailblazer::Activity::Terminus::Success.new(semantic: :finished)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)
      step **MyTest.options_for_mock_terminus(task: my_finished, semantic: :finished)

      step task: my_exec_context.method(:a), id: :a,
        Output(:failure) => Track(:failure),
        Output(:success) => Track(:success),
        Output(:finished) => Track(:finished), # we don't specify the "custom" signal here.
        outputs: {
          success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success), # we override this one.
          failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
          finished: Trailblazer::Activity::Output.new(Object, :finished),
        }
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyFailure, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: my_finished, target_ctx: {seq: [], a: Object}
  end

  it "no {:outputs}" do
    my_exec_context = T.def_tasks(:a)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus
      # step **MyTest.options_for_mock_terminus(task: MyFailure, semantic: :failure)
      # step **MyTest.options_for_mock_terminus(task: my_finished, semantic: :finished)

      step task: my_exec_context.method(:a), id: :a,
        Output(:success, signal: Trailblazer::Activity::Right) => Track(:success),

        Output(:failure) => Track(:failure),
        Output(:success) => Track(:success),
        outputs: {}
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
  end

  it "Id()" do
    my_exec_context = T.def_tasks(:a, :b)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus

      my_generic_outputs = {
        success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
        failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
      }

      step task: my_exec_context.method(:a), id: :a,
        outputs: my_generic_outputs,
        Output(:failure) => Id(:b),
        Output(:success) => Track(:success)

      step task: my_exec_context.method(:b), id: :b,
        magnetic_to: :random,
        outputs: my_generic_outputs,
        Output(:success) => Track(:success)
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess
    assert_run my_topology.to_h[:circuit], seq: [:a, :b], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Left}
  end

  it "Terminus() points to existing terminus" do
    my_exec_context = T.def_tasks(:a, :b)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus # success.

      my_generic_outputs = {
        failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
      }

      step task: my_exec_context.method(:a), id: :a,
        outputs: my_generic_outputs,
        Output(:failure) => Terminus(:success)
    end

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: MyTest::MySuccess, target_ctx: {seq: [], a: Trailblazer::Activity::Left}

    assert_outputs my_topology, success: MyTest::MySuccess
  end

  it "Terminus() points to new terminus" do
    my_exec_context = T.def_tasks(:a, :b)

    my_topology = Class.new(Trailblazer::Activity::DSL::Topology) do
      self.config.builder = Trailblazer::Activity::DSL::Builder.new(**OutputTuplesTest.my_options_for_builder)

      step **MyTest.options_for_mock_terminus # success.

      my_generic_outputs = {
        failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
      }

      step task: my_exec_context.method(:a), id: :a,
        outputs: my_generic_outputs,
        Output(:failure) => Terminus(:timeout)
    end

    timeout_terminus = my_topology.to_h[:outputs][:timeout].signal
    assert_equal timeout_terminus.semantic, :timeout # make sure we got the right terminus! :)

    assert_run my_topology.to_h[:circuit], seq: [:a], terminus: timeout_terminus, target_ctx: {seq: [], a: Trailblazer::Activity::Left}

    assert_outputs my_topology, success: MyTest::MySuccess, timeout: timeout_terminus
  end

  it "Terminus() doesn't override existing {:adds_for_sequence}" do

  end

  it "End()" do

  end

  # Here, the {:outputs} contains "too many" outputs, the :received output connector isn't configured,
  # and, eventually, not connected.
  #
  # Idea here is to make sure that features don't leak into other Topologys.
  # We test this here since the {:outputs} option is an OutputTuples feature.
  it "Topology only wires [:success, :failure] {:outputs} automatically, the {received} output isn't connected" do
    topology_classes = {Trailblazer::Activity::Path => [:success, [1, :a, :b]], Trailblazer::Activity::Railway=> [:failure, [1, :a]], Trailblazer::Activity::FastTrack=> [:failure, [1, :a]]}

    my_received_signal = Class.new(Trailblazer::Activity::Signal)

    for topology_class, (expected_terminus, expected_seq) in topology_classes
      # puts "@@@@@ #{topology_class.inspect}"
      my_path = Class.new(topology_class) do
        step :a,
          outputs: {
            success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
            failure: Trailblazer::Activity::Output.new(Trailblazer::Activity::Left, :failure),
            received: Trailblazer::Activity::Output.new(my_received_signal, :received), # this doesn't get wired, even though it's here.
          }
        step :b

        include T.def_steps(:a, :b)
      end

      assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :b]
      assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(expected_terminus).signal, seq: expected_seq, target_ctx: {seq: [1], a: Trailblazer::Activity::Left}
      assert_raises KeyError do
        assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: expected_seq, target_ctx: {seq: [1], a: my_received_signal}
      end
    end
  end

  # Here, the {:outputs} contains less outputs than in the Topology's defaults.
  # However, our :outputs overrides the default one ...
  it "currently breaks when we don't have a {:failure} output" do
    # RuntimeError: No `failure` output found for :a and outputs {:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}
    # DISCUSS: should we introduce a {failure: false} option, similar to FastTrack options?
    # DISCUSS: this should be tested in railway_test.
    assert_raises do
      Class.new(Trailblazer::Activity::Railway) do
        step :a,
          outputs: {
            success: Trailblazer::Activity::Output.new(Trailblazer::Activity::Right, :success),
            # no :failure output
          }
        step :b

        include T.def_steps(:a, :b)
      end
    end

    # assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :b]
    # assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(expected_terminus).signal, seq: expected_seq, target_ctx: {seq: [1], a: Trailblazer::Activity::Left}
  end
end
