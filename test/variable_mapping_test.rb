require "test_helper"

class VariableMappingTest < Minitest::Spec
  class << self
    def model(ctx, a:, b: 1, **)
      ctx[:a] = a + 1
      ctx[:b] = b + 2 # :b never comes in due to {:input}
      ctx[:c] = 3     # don't show outside!
    end
  end

  it "allows array and hash" do

    activity = Class.new(Trailblazer::Activity::Path) do
      # a => a, ctx[:model].id => id
      step VariableMappingTest.method(:model), input: [:a], output: {:a => :model_a, :b => :model_b}
      # step task: Uuid,      input: [:a, :model_a], output: { :a=>:uuid_a }
    end

    ctx = { a: 0, b: 9 }

    signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [ctx, {}],
      bla: 1)

    # signal.must_equal activity.outputs[:success].signal
    ctx.inspect.must_equal %{{:a=>0, :b=>9, :model_a=>1, :model_b=>3}}
  end

  it "allows procs, too" do
    skip "move me to DSL"

    _nested = nested

    activity = Module.new do
      extend Activity::Path()

      # a => a, ctx[:model].id => id
      task task: Model,     input: ->(ctx, a:, **) { { :a => a+1 } }, output: ->(ctx, a:, **) { { model_a: a } }
      task task: _nested,    _nested.outputs[:success] => Track(:success)
      task task: Uuid,      input: [:a, :model_a], output: { :a=>:uuid_a }
    end

    signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
      [
        options = { :a => 1 },
        {},
      ],

    )

    signal.must_equal activity.outputs[:success].signal
    options.must_equal({:a=>1, :model_a=>4, :c=>1, :uuid_a => 5 })
  end
end

=begin

VariableMapping::Extension(
Trailblazer::Activity::TaskWrap::Input.new(input),
            Trailblazer::Activity::TaskWrap::Output.new(output))
)

=end
