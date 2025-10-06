require "test_helper"
require "trailblazer/activity/dsl/linear/feature/variable_mapping/runtime/filter_step"


class VMRefactoringTest < Minitest::Spec
  let(:vm) { Trailblazer::Activity::DSL::Linear::VariableMapping }

  # Here, we test filter building from DSL to actual tw/pipeline steps.
  # We do not test how the actual input/output pipeline is composed.
  it "here, i test the old Filter features by using the respective FiltersBuilder.call method that translates from the DSL" do
    # => In() => [:a]
    filter, _ = vm::DSL.In().([:a])
    wrap_ctx, _ = filter.({aggregate: {}}, [[{}, {}]]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:a=>nil}})

    # => In() => ->(*) { {...} }
    filter, _ = vm::DSL.In().(->(*) { {a: "-ha!"} })
    wrap_ctx, _ = filter.({aggregate: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:a=>"-ha!"}})

    # => In() => {:a => :A}
    filter, _ = vm::DSL.In().({:a => :A})
    wrap_ctx, _ = filter.({aggregate: {}}, [[{a: "-ha!"}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:A=>"-ha!"}})

    # => Out() => [:model]
    filter, _ = vm::DSL.Out().([:model])
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {model: Object, user: Module}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Object}, :returned_ctx=>{:model=>Object, :user=>Module}})

    # => Out() => {:model => :a_model}
    filter, _ = vm::DSL.Out().({:model => :a_model})
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {model: Object}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:a_model=>Object}, :returned_ctx=>{:model=>Object}})

    # => Out() => ->(*) { {...} }
    filter, _ = vm::DSL.Out().(->(*) { {record: Object} })
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {model: Object, user: Module}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:record=>Object}, :returned_ctx=>{:model=>Object, :user=>Module}})

    # => Out(read_from_aggregate: true) => {:_model => :model}
    filter, _ = vm::DSL.Out(read_from_aggregate: true).({:_model => :model})
    wrap_ctx, _ = filter.({aggregate: {_model: Object}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:_model=>Object, :model=>Object}, :returned_ctx=>{}})

    # => Out(delete: true) => [:record]
    filter, _ = vm::DSL.Out(delete: true).([:record])
    wrap_ctx, _ = filter.({aggregate: {model: Object, record: Class}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Object}, :returned_ctx=>{}})

    # Out(with_outer_ctx: true) => ->(*) { snippet }
    filter, _ = vm::DSL.Out(with_outer_ctx: true).(->(ctx, outer_ctx:, **) { {out_model: outer_ctx[:model]} })
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{model: Object}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:out_model=>Object}, :returned_ctx=>{}})

    # Inject() => [:model]
    filter, _ = vm::DSL.Inject().([:model])
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{model: Object}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Object}, :returned_ctx=>{}})
      # ctx empty
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{}, :returned_ctx=>{}})

    # DISCUSS: oh, this doesn't work, yet!
    # Inject() => {:model => :record}
    # filter, _ = vm::DSL.Inject().({:model => :record})
    # wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{model: Object}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    # assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:record=>Object}, :returned_ctx=>{}})
    #   # ctx empty
    # wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    # assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{}, :returned_ctx=>{}})

    # Inject(:model) => ->(*) { "value" }
    filter, _ = vm::DSL.Inject(:model).(->(*) { Object })
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{model: Class}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Class}, :returned_ctx=>{}})
    # ctx empty, defaulting
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Object}, :returned_ctx=>{}})

    # Inject(:model, override: true) => ->(*) { "value" }
    filter, _ = vm::DSL.Inject(:model, override: true).(->(*) { Class })
    wrap_ctx, _ = filter.({aggregate: {}, returned_ctx: {}}, [[{model: Object}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:model=>Class}, :returned_ctx=>{}})

    # Inject(:model, pass_aggregate: true) => ->(*) { "value" }
    filter, _ = vm::DSL.Inject(:model, pass_aggregate: true).(->(ctx, aggregate:, **) { aggregate[:record] })
    wrap_ctx, _ = filter.({aggregate: {record: Object}, returned_ctx: {}}, [[{}, {}], exec_context: nil]) # taskWrap/pipeline interface.
    assert_equal CU.inspect(wrap_ctx), %({:aggregate=>{:record=>Object, :model=>Object}, :returned_ctx=>{}})
  end

  it "here, i test the alternative approach with Activitys" do
  # In() => [:a]

    user_filter = vm::VariableFromCtx.new(variable_name: :a)
    # filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)
    filter = user_filter # no Ciruit::Step wrapping as VariableFromCtx exposes circuit-step interface.

    wrap_ctx = {
      aggregate: {},
      original_args: [[{a: "a", model: Object}, {}], {}],
    }

    runtime_step = vm::Runtime::FilterStep.build(
      filter:     filter,
      write_name: :a
    )

    # Don't call it with {TaskWrap.invoke} as we don't need/want this logic here (performance)!
    signal, (ctx, _) = runtime_step.(wrap_ctx)

    assert_equal CU.inspect(ctx[:aggregate]), %({:a=>"a"})

  # In() => ->(*) { "value" }
    user_filter = ->(ctx, a:, **) { {id: a} }
    filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

    ctx = {
      aggregate: {},
      original_args: [[{a: "a", model: Object}, {}], {exec_context: self}],
      filter: filter,
      # write_name: :a # we don't need a {:write_name} here, it's a hash-producing user_filter.
    }

    runtime_filter = Class.new(Filter::MergeVariables) do
      step nil, delete: :wrap_value_with_hash # DISCUSS: how do we compose those differing logic flows?
    end

    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:id=>"a"})

  # Out() => [:model]
    user_filter = vm::VariableFromCtx.new(variable_name: :model)

    ctx = {
      aggregate: {},
      original_args: [[{id: 1}, {}], {}],
      filter: user_filter,
      write_name: :model,
      returned_ctx: {model: Object, action: :update}, # from the step logic
    }

    # Don't call it with {TaskWrap.invoke} as we don't need/want this logic here (performance)!
    signal, (ctx, _) = Filter::MergeVariables::Output.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>Object})

  # Out(with_outer_ctx: true) => ->(*) { value }
    user_filter = ->(ctx, params:, outer_ctx:, **) {
      {model: "#{params.inspect} / #{outer_ctx[:slug]}" }
    }
    filter = Trailblazer::Activity::Circuit.Step(user_filter)

    ctx = {
      aggregate: {},
      original_args: [[{model: Object, slug: "1cda6"}, {}], {}],
      filter: filter,
      # write_name: :model,
      returned_ctx: {params: {id: 2}, action: :update}, # from the step logic
    }

    runtime_filter = Class.new(Filter::MergeVariables::Output) do
      step nil, delete: :wrap_value_with_hash # DISCUSS: how do we compose those differing logic flows?
      step :with_outer_ctx, after: :args_for_filter
    end

    # Don't call it with {TaskWrap.invoke} as we don't need/want this logic here (performance)!
    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>"{:id=>2} / 1cda6"})

  # Inject => [:model]
    filter = vm::VariableFromCtx.new(variable_name: :model)
    # filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)
    condition = vm::VariablePresent.new(variable_name: :model)

    ctx = {
      condition: condition,
      aggregate: {},
      original_args: [[{}, {}], {exec_context: self}],
      filter: filter,
      write_name: :model # we don't need a {:write_name} here, it's a hash-producing user_filter.
    }

    signal, (ctx, _) = Filter::MergeVariables::Conditioned.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({})

    # variable is present in ctx, condition is true, it's set!
    ctx.merge!(
      original_args: [[{model: Object}, {}], {exec_context: self}],
    )

    signal, (ctx, _) = Filter::MergeVariables::Conditioned.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>Object})

    # variable is present in ctx, but {nil}.
    ctx.merge!(
      aggregate: {},
      original_args: [[{model: nil}, {}], {exec_context: self}],
    )
# require "trailblazer/developer"
# require "trailblazer/invoke"
# require "trailblazer/invoke/activity"
    signal, (ctx, _) = Filter::MergeVariables::Conditioned.([ctx, {}])
    # signal, (ctx, _) = Trailblazer::Developer.wtf?(Filter::MergeVariables::Conditioned, ctx)

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>nil})

  # Inject(:model) => ->(*) { "default" }
    filter = vm::VariableFromCtx.new(variable_name: :model)
    user_filter = ->(*) { Object }
    filter_for_default = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

    condition = vm::VariablePresent.new(variable_name: :model)

    ctx = {
      condition: condition,
      aggregate: {},
      original_args: [[{}, {}], {exec_context: self}],
      filter: filter, # VariableFromCtx
      filter_for_default: filter_for_default,
      write_name: :model # we don't need a {:write_name} here, it's a hash-producing user_filter.
    }

    signal, (ctx, _) = Filter::MergeVariables::Defaulted.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>Object})

    # value is present, but {nil}
    ctx.merge!(
      aggregate: {},
      original_args: [[{model: nil}, {}], {exec_context: self}],
    )

    signal, (ctx, _) = Filter::MergeVariables::Defaulted.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>nil})

  # Inject(pass_aggregate: true) => ->(ctx, aggregate:, **) { snippet }
    user_filter = ->(ctx, params:, aggregate:, **) { "#{params.inspect} / #{aggregate.inspect}" }
    filter_for_default = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

    ctx = {
      condition: condition,
      aggregate: {id: 1},
      original_args: [[{params: {}}, {}], {exec_context: self}],
      filter: filter, # VariableFromCtx
      filter_for_default: filter_for_default,
      write_name: :model # we don't need a {:write_name} here, it's a hash-producing user_filter.
    }

    runtime_filter = Class.new(Filter::MergeVariables::Defaulted) do
      step :pass_aggregate, after: :args_for_filter
    end

    # Inject defaulting called.
    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:id=>1, :model=>"{} / {:id=>1}"})

    # {:model} is present, Inject defaulting not called.
    ctx = ctx.merge(
      aggregate: {id: 1},
      original_args: [[{params: {}, model: Class}, {}], {exec_context: self}],
    )
    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:id=>1, :model=>Class})

  # Inject(pass_aggregate: true, override: true) => ->(ctx, aggregate:, **) { snippet }
    user_filter = ->(ctx, params:, aggregate:, **) { "#{params.inspect} / #{aggregate.inspect}" }
    filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

    runtime_filter = Class.new(Filter::MergeVariables) do # NOTE: we are using MergeVariables here for Inject(..., override: true)!
      step :pass_aggregate, after: :args_for_filter
    end

    ctx = {
      aggregate: {id: 1},
      original_args: [[{params: {}}, {}], {exec_context: self}], # no {:model}, default is called
      filter: filter,
      write_name: :model,
    }

    # filter is run.
    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:id=>1, :model=>"{} / {:id=>1}"})

    # {:model present}, filter still run.
    ctx = ctx.merge(
      aggregate: {id: 1},
      original_args: [[{params: {}, model: Class}, {}], {exec_context: self}],
    )
    signal, (ctx, _) = runtime_filter.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:id=>1, :model=>"{} / {:id=>1}"})

raise "what other features to add?"
# benchmark with old implementation

  end
end
