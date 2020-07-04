require "test_helper"

class StateTest < Minitest::Spec
  it "what" do
    initial_fields = {}.freeze

  # initial is initial
    state = Trailblazer::Activity::DSL::Linear::State.new(normalizers: {}, initial_sequence: [], fields: initial_fields, **{})

    _(state.to_h[:fields]).must_equal initial_fields

  # write
    state.update_options(a: "yo")

    _(initial_fields.inspect).must_equal %{{}}
    _(state.to_h[:fields].inspect).must_equal %{{:a=>\"yo\"}}
  end
end
