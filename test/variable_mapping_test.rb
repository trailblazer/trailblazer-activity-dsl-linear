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

  it "allows ctx aliasing with nesting and :input/:output" do
    model = Class.new(Trailblazer::Activity::Path) do
      step :model_add

      def model_add(ctx, model_from_a:, **)
        ctx[:model_add] = model_from_a.inspect
      end
    end

    activity = Class.new(Trailblazer::Activity::Path) do
      step VariableMappingTest.method(:model), input: [:a], output: {:a => :model_a, :b => :model_b}
      step Subprocess(model)
      step VariableMappingTest.method(:uuid), input: {:a => :a, :b => :my_b}, output: [:b]
    end

    ctx           = {a: 0, b: 9}
    flow_options  = { context_options: { container_class: Trailblazer::Context::Container::WithAliases, aliases: { model_a: :model_from_a } } }

    ctx = Trailblazer::Context(ctx, {}, flow_options[:context_options])

    signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [ctx, flow_options], **{})

    ctx.to_hash.inspect.must_equal %{{:a=>0, :b=>108, :model_a=>1, :model_b=>3, :model_add=>\"1\", :model_from_a=>1}}
  end
end
