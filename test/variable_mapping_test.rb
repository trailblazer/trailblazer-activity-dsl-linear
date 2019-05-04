require "test_helper"

class VariableMappingTest < Minitest::Spec
  class << self
    def model(ctx, a:, b: 1, **)
      ctx[:a] = a + 1
      ctx[:b] = b + 2 # :b never comes in due to {:input}
      ctx[:c] = 3     # don't show outside!
    end

    def uuid(ctx, a:, my_b:, **)
      ctx[:a] = a + 99 # not propagated outside
      ctx[:b] = ctx[:a] + my_b # 99 + 9
      ctx[:c] = 3     # don't show outside!
    end
  end

  it "allows array and hash" do
    activity = Class.new(Trailblazer::Activity::Path) do
      step VariableMappingTest.method(:model), input: [:a], output: {:a => :model_a, :b => :model_b}
      step VariableMappingTest.method(:uuid), input: {:a => :a, :b => :my_b}, output: [:b]
    end

    ctx = { a: 0, b: 9 }

    signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [ctx, {}],
      bla: 1)

    # signal.must_equal activity.outputs[:success].signal
    ctx.inspect.must_equal %{{:a=>0, :b=>108, :model_a=>1, :model_b=>3}}
  end

  it "allows procs, too" do
    activity = Class.new(Trailblazer::Activity::Path) do
      step VariableMappingTest.method(:model), input: ->(ctx, a:, **) { { :a => a+1 } }, output: ->(ctx, a:, **) { { model_a: a } }
      # step VariableMappingTest.method(:uuid),  input: [:a, :model_a], output: { :a=>:uuid_a }
    end

    signal, (options, flow_options) = Activity::TaskWrap.invoke(activity,
      [
        options = { :a => 1 },
        {},
      ],

    )

    # signal.must_equal activity.outputs[:success].signal
    options.must_equal({:a=>1, :model_a=>3})
  end
end
