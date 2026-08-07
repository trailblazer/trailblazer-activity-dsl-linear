require "test_helper"

class TopologyPathTest < Minitest::Spec
  it "empty Path can be run" do
    my_path = Class.new(Trailblazer::Activity::Path) do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "empty Path() can be run" do
    my_path, _ = Trailblazer::Activity::Path() do
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: []
  end

  it "step can return Right" do
    canonical_normalizer_for_step = Trailblazer::Activity::DSL::Normalizer::Step

    # add the Output() feature:
    extended_canonical_normalizer_for_step = Trailblazer::Circuit::Adds.(
      canonical_normalizer_for_step,
      [
        :normalize_wirings, Trailblazer::Activity::DSL::Feature::OutputTuples::Normalizer::Node,
        :before, :build_sequence_row
      ],
    )

    # add Path specific behavior:
    extended_canonical_normalizer_for_step = Trailblazer::Circuit::Adds.(
      extended_canonical_normalizer_for_step,
      [
        :add_path_options, Trailblazer::Activity::Path::Normalizer::Node,
        :before, :normalize_wirings # we're dependent on {OutputTuples}!
      ],
    )

    normalizers = {
      # step: Trailblazer::Activity::DSL::Normalizer::Step
      step: extended_canonical_normalizer_for_step,
    }


    my_path = Class.new(Trailblazer::Activity::Path) do
      config.builder.normalizers = normalizers # FIXME: this must be done in a neat way!

      step :a
      step :b

      include T.def_steps(:a, :b)
    end

    assert_run my_path.to_h[:circuit], terminus: my_path.to_h[:outputs].fetch(:success).signal, seq: [:a, :b]
  end

  it "step can return Left" do

  end
end
