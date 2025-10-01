require "test_helper"

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
    module Filter
      class MergeVariables < Trailblazer::Activity::Railway # TODO: performance, Path, Runner, etc.
        step :args_for_filter
        step :call_filter
        step :wrap_value_with_hash
        step :merge_variables_into_aggregate

        def args_for_filter(ctx, original_args:, **)
          ctx[:args_for_filter] = original_args
        end

        def call_filter(ctx, filter:, args_for_filter:, **)
          # Calling a filter with a circuit-step interface means we
          # need to pass [[ctx, flow_options], **cicuit_args]
          #
          # DISCUSS: ctx needs to be different sometimes, e.g. in Out, how to do that?
          variable, _ = filter.(args_for_filter[0], **args_for_filter[1]) # circuit-step interface

          ctx[:value] = variable
        end

        def wrap_value_with_hash(ctx, value:, write_name:, **)
          ctx[:value] = {write_name => value}
        end

        def merge_variables_into_aggregate(ctx, aggregate:, value:, **)
          ctx[:aggregate] = merge_variables(value, aggregate)
        end

        private def merge_variables(variables, aggregate, receiver = aggregate)
          aggregate = receiver.merge(variables)
        end

        class Output < MergeVariables
          def args_for_filter(ctx, original_args:, returned_ctx:, **)
            # super(ctx, **ctx, original_args: [[new_ctx, original_args[0][1]], original_args[1]])
            ctx[:args_for_filter] = [[returned_ctx, original_args[0][1]], original_args[1]]
          end

          # FIXME: structure!
          # DISCUSS: {:with_outer_ctx} only makes sense with callable filter.
          def with_outer_ctx(ctx, original_args:, args_for_filter:, **)
            new_ctx = args_for_filter[0][0].merge(outer_ctx: original_args[0][0])
            ctx[:args_for_filter] = [[new_ctx, args_for_filter[0][1]], args_for_filter[1]]
          end
        end

        # Set variable on ctx if {condition} is true.
        class Conditioned < MergeVariables # currently used for Inject.
          step :evaluate_condition, after: :args_for_filter

          def evaluate_condition(ctx, condition:, args_for_filter:, **)
            # DISCUSS: should we use #call_filter here?
            call_filter({}, filter: condition, args_for_filter: args_for_filter) # result is value.
          end
        end
      end
    end # Filter

  # In() => [:a]

    user_filter = vm::VariableFromCtx.new(variable_name: :a)
    # filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)
    filter = user_filter # no Ciruit::Step wrapping as VariableFromCtx exposes circuit-step interface.

    ctx = {
      aggregate: {},
      original_args: [[{a: "a", model: Object}, {}], {}],
      filter: filter,
      write_name: :a
    }

    # Don't call it with {TaskWrap.invoke} as we don't need/want this logic here (performance)!
    signal, (ctx, _) = Filter::MergeVariables.([ctx, {}])

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
    user_filter = ->(*) { Object }
    filter = Trailblazer::Activity::Circuit.Step(user_filter, option: true)

    condition = vm::VariableFromCtx.new(variable_name: :model)

    ctx = {
      condition: condition,
      aggregate: {},
      original_args: [[{}, {}], {exec_context: self}],
      filter: filter,
      write_name: :model # we don't need a {:write_name} here, it's a hash-producing user_filter.
    }

    signal, (ctx, _) = Filter::MergeVariables::Conditioned.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({})

    ctx.merge!(
      original_args: [[{model: Object}, {}], {exec_context: self}],
    )

    signal, (ctx, _) = Filter::MergeVariables::Conditioned.([ctx, {}])

    assert_equal CU.inspect(ctx[:aggregate]), %({:model=>Object})
  end
end
