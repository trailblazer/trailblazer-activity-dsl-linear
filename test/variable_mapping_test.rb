require "test_helper"

class VariableMappingTest < Minitest::Spec

# Composing input/output
# Composing Inject()
  it "Inject(): allows [] and ->{}" do
    module T
      class Create < Trailblazer::Activity::Railway
        step :write,
          Inject() => [:date, :time],
          Inject() => {current_user: ->(ctx, **kws) { ctx.keys.inspect + kws.inspect }} # FIXME: test/design kws here

        def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
          ctx[:log] = "Called @ #{time} and #{date.inspect} by #{current_user}!"
          ctx[:private] = ctx.keys.inspect
        end
      end
    end

  ## this must break because of missing {:date} - it is not defaulted, only injected when present.
    exception = assert_raises do
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{time: "yesterday", model: Object}, {}])
    end
    assert_match /missing keywords?: :?date/, exception.message

  #@ {:time} is passed-through.
  #@ {:date} is passed-through.
  #@ {:current_user} is defaulted through Inject()
  #@ Injections are not visible outside.
  ## Note that Inject()s are put "on top" of the default input, no whitelisting is happening, we can still see {:model}.
    assert_invoke T::Create, time: "yesterday", date: "today", model: Object, expected_ctx_variables: {
      log: "Called @ yesterday and \"today\" by [:seq, :time, :date, :model]#{{:seq=>[], :time=>"yesterday", :date=>"today", :model=>Object}}!",
      private: "[:seq, :time, :date, :model, :current_user, :log]"
    }

  ## {:time} is defaulted through kw
  ## {:current_user} is defaulted through Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{date: "today"}, {}])
    assert_equal CU.inspect(ctx), '{:date=>"today", :log=>"Called @ Time.now and \"today\" by [:date]{:date=>\"today\"}!", :private=>"[:date, :current_user, :log]"}'

  ## {:current_user} is passed-through
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{date: "today", current_user: Object}, {}])
    assert_equal CU.inspect(ctx), '{:date=>"today", :current_user=>Object, :log=>"Called @ Time.now and \"today\" by Object!", :private=>"[:date, :current_user, :log]"}'
  end

  it "Inject() adds variables to In() when configured" do
    module TT
      class Create < Trailblazer::Activity::Railway
        step :write,
          Inject() => [:date, :time],
          Inject() => {current_user: ->(ctx, **) { ctx.keys.inspect }},
          In() => [:model],
          In() => {:something => :thing}

        def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
          ctx[:log] = "Called @ #{time} and #{date.inspect} by #{current_user}!"
          ctx[:private] = ctx.keys.inspect
          ctx[:private] += ctx[:model].inspect
        end
      end
    end

  ## we can only see variables combined from Inject() and In() in the step.
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TT::Create, [{date: "today", model: Object, something: 99}, {}])
    assert_equal CU.inspect(ctx), '{:date=>"today", :model=>Object, :something=>99, :log=>"Called @ Time.now and \"today\" by [:date, :model, :something]!", :private=>"[:date, :current_user, :model, :thing, :log]Object"}'
  end

  #@ unit test
  it "with default Out(), it doesn't merge variables to the outer ctx that haven't been explicitely written to the inner ctx" do
    module EEE
      class Create < Trailblazer::Activity::Railway
        step :write,
          # we create a new {:seq} variable for this scope. this one won't be visible outside.
          In() => ->(ctx, seq:, **) { {seq: [:something, :new]} }

        def write(ctx, seq:, **)
          ctx[:seq] << :write # we're writing to the new {:seq} variable. This doesn't create a new entry in mutable_options on the new ctx. So this won't be merged in the automatic default Out().
        end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(EEE::Create, [{seq: ["today"]}, {}])
    assert_equal CU.inspect(ctx), %{{:seq=>["today"]}} #= the additions from the In() filter and from `#write` are missing.
  end

  it "In() DSL: single {In() => [:current_user]}" do
    module RR
      class Create < Trailblazer::Activity::Railway
        step :write,
          In() => [:current_user]

        def write(ctx, model: 9, current_user:, **)
          ctx[:incoming] = [model, current_user, ctx.keys]
        end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RR::Create, [{time: "yesterday", model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>Object, :incoming=>[9, nil, [:current_user]]}}
    # pass {:current_user} from the outside
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :incoming=>[9, Module, [:current_user]]}}
  end

  it "Output() DSL: single {Out() => [:current_user]}" do
    module RRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => [:model]

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside!
        end
      end
    end

  ## {:private} invisible in outer ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module}}

    # no {:model} for invocation
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRR::Create, [{time: "yesterday", current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :model=>[Module, [:time, :current_user, :private]]}}
  end

  it "Output() DSL: single {Out() => {:model => :user}}" do
    module RRRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => {:model => :song}

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song}!
        end
      end
    end

  ## {:model} is in outer ctx as we passed it into invocation, {:private} invisible:
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :song=>[Module, [:time, :model, :current_user, :private]]}}

    # no {:model} in outer ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRR::Create, [{time: "yesterday", current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :song=>[Module, [:time, :current_user, :private]]}}
  end

  it "Out() DSL: multiple overlapping {Out() => {:model => :user}} will create two aliases" do
    module RRRRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => {:model => :song, :current_user => :user},
        ## we refer to {:model} a second time here, it's still there in the Out pipe.
        ## and won't be in the final output hash.
          Out() => {:model => :hit}
        # }

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
        end
      end
    end

    # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :song=>[Module, [:time, :model, :current_user, :private]], :user=>Module, :hit=>[Module, [:time, :model, :current_user, :private]]}}

    # no {:model} in original ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :song=>[Module, [:time, :current_user, :private]], :user=>Module, :hit=>[Module, [:time, :current_user, :private]]}}
  end

  it "Out() DSL: Dynamic lambda {Out() => ->{}}" do
    module RRRRRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => -> (inner_ctx, model:, private:, **) {
            {
              :model    => model,
              :private  => private.gsub(/./, "X") # CC number should be Xs outside.
            }
          }

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
        end
      end
    end

    # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module, :private=>"XXX"}}

    # no {:model} in original ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :model=>[Module, [:time, :current_user, :private]], :private=>"XXX"}}
  end

  it "Out() DSL: Dynamic lambda {Out() => ->{}}, order matters!" do
    module RRRRRRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => -> (inner_ctx, model:, private:, **) {
            {
              :model    => model,
              :private  => private.gsub(/./, "X") # CC number should be Xs outside.
            }
          },
          Out() => ->(inner_ctx, model:, **) { {:model => "<#{model}>"} }

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
        end
      end
    end

    # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>"<[Module, [:time, :model, :current_user, :private]]>", :current_user=>Module, :private=>"XXX"}}

    # no {:model} in original ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :model=>"<[Module, [:time, :current_user, :private]]>", :private=>"XXX"}}
  end

  # FIXME: remove me, redundant.
  it "Out() DSL: { Out(with_outer_ctx: true) => ->{} }" do
    module RRRRRRRR
      class Create < Trailblazer::Activity::Railway
        step :create_model,
          Out() => -> (inner_ctx, model:, private:, **) {
            {
              :model    => model,
              :private  => private.gsub(/./, "X") # CC number should be Xs outside.
            }
          },
          Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx, model:, **) { {:song => model, private: outer_ctx[:private].to_i + 1} }

        def create_model(ctx, current_user:, **)
          ctx[:private] = "hi!"
          ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
        end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module, :private=>1, :song=>[Module, [:time, :model, :current_user, :private]]}}

    # no {:model} in original ctx
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRRR::Create, [{time: "yesterday", current_user: Module, private: 9}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :current_user=>Module, :private=>10, :model=>[Module, [:time, :current_user, :private]], :song=>[Module, [:time, :current_user, :private]]}}
  end

  it "{Out()} with {:output} warns and {:output} overrides everything" do
    output, err = capture_io {
      module S
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => -> (inner_ctx, model:, private:, **) { {_private: private} },
            Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx, model:, **) { {} },
            output: {:model => :song}

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys]
          end
        end
      end
    }
    line_number = __LINE__ - 12

    assert_equal err.split("\n").find_all { |line| line[0] != "/" }.join("\n"), %([Trailblazer] #{File.realpath(__FILE__)}:#{line_number} You are mixing #{{:input=>nil, :output=>{:model=>:song}, :inject=>nil}} with In(), Out() and Inject().
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.
[Trailblazer] #{File.realpath(__FILE__)}:#{line_number} The positional argument `outer_ctx` is deprecated, please use the `:outer_ctx` keyword argument.
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.)

    assert_invoke S::Create, time: "yesterday", model: Object, current_user: Module, expected_ctx_variables: {_private: "hi!", :song=>[Module, [:seq, :time, :model, :current_user, :private]]}
  end

  it "{In()} with {:input} warns and {:input} is mixed with In()" do
    output, err = capture_io {
      module RRRRRRRRRR
        class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
          step :write,
            input:     [:model],
            In() => [:current_user],
            # In() => ->(ctx, **) { raise }
            In() => ->(ctx, **) { {} }

          def write(ctx, model:, **)
            ctx[:incoming] = [model, ctx.keys]
          end
        end
      end
    }
    line_number = __LINE__ - 12

    assert_equal err.split("\n")[0..1].join("\n"), %([Trailblazer] #{File.realpath(__FILE__)}:#{line_number} You are mixing #{{:input=>[:model], :output=>nil, :inject=>nil}} with In(), Out() and Inject().
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.)

    assert_invoke RRRRRRRRRR::Create, time: "yesterday", model: Object, expected_ctx_variables: {:incoming=>[Object, [:current_user, :model]]}
  end

  it "merging multiple input/output steps via In() DSL" do
    module R
      class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
        step :write,
          # all filters can see the original ctx:
          Inject() => {time: ->(ctx, **) { 99 }},
          In() => [:model],
          In() => [:current_user],
          # we can still see {:time} here:
          In() => ->(ctx, model:, time:nil, **) { {model: model.to_s + "hello! #{time}"} },
          Out() => ->(ctx, model:, **) { {out: [model, ctx[:incoming]]} }

        def write(ctx, model:, current_user:, **)
          ctx[:incoming] = [model, current_user, ctx.to_h]
        end
      end

    #@ Is the taskWrap inherited?
      class Update < Create
      end

      class Upsert < Update
        step :write, replace: :write,
          # inherit: [:variable_mapping],
        ## this overrides the existing taskWrap
          In() => [:model, :current_user]
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Create, [{time: "yesterday", model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :model=>Object, :out=>[\"Objecthello! yesterday\", [\"Objecthello! yesterday\", nil, {:time=>"yesterday", :model=>"Objecthello! yesterday", :current_user=>nil}]]}}

  ## {:time} is defaulted by Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Create, [{model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :out=>["Objecthello! ", ["Objecthello! ", nil, {:time=>99, :model=>"Objecthello! ", :current_user=>nil}]]}}


  ## Inheriting I/O taskWrap filters
    ## {:time} is defaulted by Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Update, [{model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :out=>[\"Objecthello! \", [\"Objecthello! \", nil, {:time=>99, :model=>"Objecthello! ", :current_user=>nil}]]}}

  ## currently, the In() in Upsert overrides the inherited taskWrap.
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Upsert, [{model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :incoming=>[Object, nil, {:model=>Object, :current_user=>nil}]}}

  end

  #@ unit test
  it "uses and returns the correct {flow_options}" do
    lets_change_flow_options = ->((ctx, flow_options), circuit_options) do
      ctx[:seq] = ctx[:seq] + [:lets_change_flow_options]

    # allows to change flow_options in the task.
      flow_options = flow_options.merge(coffee: true)

      [Trailblazer::Activity::Right, [ctx, flow_options]]
    end

    activity = Class.new(Trailblazer::Activity::Railway) do
      step task: lets_change_flow_options,
        In() => ->(ctx, seq:, model_input:, **) { {seq: seq + [:model_input]} }#, #@ test if In() kicks in.
        # Out() => ->(original_ctx, seq:, **) { {seq: seq} }
      step :uuid

      include ::T.def_steps(:uuid)
    end

    signal, (ctx, flow_options) = Activity::TaskWrap.invoke(
      activity,
      [
        {seq: [], model_input: "great!"},
        {yo: 1} #@ flow_options to be changed by the step.
      ]
    )

    assert_equal CU.inspect(ctx), %{{:seq=>[:model_input, :lets_change_flow_options, :uuid], :model_input=>"great!"}}
    assert_equal CU.inspect(flow_options), %{{:yo=>1, :coffee=>true}}
  end

  #@ unit test
  it "i/o works for step, pass and fail and is automatically included in Path, Railway and FastTrack" do
    write_step_for = ->(strategy, method_name) do
      Class.new(strategy) do
        step :deviate
        send method_name, :write, In() => [:model],
          Out() => {:model => :write_model, :incoming => :incoming}

        def deviate(ctx, deviate: true, **)
          deviate
        end

        def write(ctx, model:, **)
          ctx[:incoming] = [model, ctx.keys]
        end
      end
    end

    #@ Path
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Path, :step), [{model: Object, ignore: 1}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

    #@ Railway
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :step), [{model: Object, ignore: 1}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :pass), [{model: Object, ignore: 1}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :fail), [{model: Object, ignore: 1, deviate: false}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :deviate=>false, :write_model=>Object, :incoming=>[Object, [:model]]}}

    #@ FastTrack
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :step), [{model: Object, ignore: 1}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :pass), [{model: Object, ignore: 1}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :fail), [{model: Object, ignore: 1, deviate: false}, {}])
    assert_equal CU.inspect(ctx), %{{:model=>Object, :ignore=>1, :deviate=>false, :write_model=>Object, :incoming=>[Object, [:model]]}}
  end

  #@ unit test
  # it "In() and Inject() execution order" do
  #   module YYY
  #     class Create < Trailblazer::Activity::Railway
  #       step :write,
  #         # all filters can see the original ctx:
  #         # Inject() => {time: ->(ctx, **) { puts "& #{ctx.keys.inspect}"; 99 }},
  #         In() => ->(ctx, model:, **) {          {model_1: model + ctx.keys} },
  #         In() => ->(ctx, model:, ignore:, **) { {model_2: model + ctx.keys} }

  #       def write(ctx, model_1:, model_2:, **)
  #         ctx[:incoming]    = [model_1, model_2]
  #         ctx[:visible_ctx] = ctx.to_h
  #       end
  #     end
  #   end

  #   signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(YYY::Create, [{model: [], ignore: 1}, {}])
  #   assert_equal CU.inspect(ctx), %{{:model=>[], :ignore=>1, :incoming=>[[asdfasdf], {:model=>Object, :current_user=>nil}]}}
  # end



  #@ unit test
  it "accepts :initial_input_pipeline as normalizer option" do
    my_input_ctx = ->(wrap_ctx, original_args) do
    # The default ctx is the original ctx but with uppercased values.
      default_ctx = wrap_ctx[:original_ctx].collect { |k,v| [k.to_s.upcase, v.to_s.upcase] }.to_h

      Trailblazer::Activity::DSL::Linear::VariableMapping.merge_variables(default_ctx, wrap_ctx, original_args)
    end

    activity = Class.new(Trailblazer::Activity::Railway) do
      input_pipe = Trailblazer::Activity::TaskWrap::Pipeline.new([
      # we use the standard input pipeline but with our own default_ctx that has UPPERCASED variables and values.
        Trailblazer::Activity::TaskWrap::Pipeline.Row("input.my_input_ctx", my_input_ctx),
        Trailblazer::Activity::TaskWrap::Pipeline.Row("input.scope", Trailblazer::Activity::DSL::Linear::VariableMapping.method(:scope)),
      ]) # DISCUSS: use VariableMapping.initial_input_pipeline here, and modify it?

      step :write,
        initial_input_pipeline: input_pipe, In() => [:model]

      def write(ctx, model:, **)
        ctx[:incoming] = [model, ctx.to_h]
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{time: "yesterday", model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{:time=>"yesterday", :model=>Object, :incoming=>[Object, {:TIME=>"YESTERDAY", :MODEL=>"OBJECT", :model=>Object}]}}
  end

  #@ unit test
  # TODO: remove this test, it's not public API anymore.
  it "accepts :initial_output_pipeline as normalizer option" do
    my_output_ctx = ->(wrap_ctx, original_args) do
      wrap_ctx[:aggregate] = wrap_ctx[:aggregate].collect { |k,v| [k.to_s.upcase, v.to_s.upcase] }.to_h

      return wrap_ctx, original_args
    end

    activity = Class.new(Trailblazer::Activity::Railway) do
      output_pipe = Trailblazer::Activity::DSL::Linear::VariableMapping::DSL.initial_output_pipeline()
      output_pipe = Trailblazer::Activity::TaskWrap::Extension([my_output_ctx, id: "my.output_uppercaser", append: "output.merge_with_original"]).(output_pipe)


      step :write,
        initial_output_pipeline: output_pipe, Out() => [:model]

      def write(ctx, model:, **)
        ctx[:current_user] = Module
      end
    end

    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{model: Object}, {}])
    assert_equal CU.inspect(ctx), %{{"MODEL"=>"OBJECT"}}
  end



    # TODO: test if injections are discarded afterwards
    # TODO: can we use Context() from VariableMapping?
    # TODO: inject: {"action.class" => Song}

    # input:, inject:
    #   input.()
    #     inject.() # take all variables from input's ctx + injected
    #     inject-out.() (just return input's ctx variables WITHOUT injected PLUS mutable?)
    #   output.()

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
    CU.inspect(ctx).must_equal %{{:a=>0, :b=>108, :model_a=>1, :model_b=>3}}
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
    _(options).must_equal({:a=>1, :model_a=>3})
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

    CU.inspect(ctx.to_hash).must_equal %{{:a=>0, :b=>108, :model_a=>1, :model_b=>3, :model_add=>\"1\", :model_from_a=>1}}
  end

  #@ unit test
  def activity_for(proc_in: self.proc_in, proc_out: self.proc_out)
    activity = Class.new(Trailblazer::Activity::Railway) do
      step task: Capture,

        In() => [:params], # 1
        In() => [:mode, :styles], # 2,3
        In() => {:current_user => :user}, # 4
        In() => proc_in, # 5

        Out() => [:result], # 1
        Out() => [:message, :status], # 2,3
        Out() => {:code => :error_code}, # 4
        Out() => proc_out, # 5

        Inject(:field) => ->(*) { :date }, # 6
        Inject() => [:key] # 7
    end
  end #activity_for

  describe "beautiful unit tests" do
    class Capture
      def self.call((ctx, flow_options), **)
        ctx[:capture] = ctx.keys
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end

    let(:proc_in)     do ->(*) { {in: 1} }   end
    let(:proc_out)    do ->(*) { {out: 99} } end

    it "benchmark" do
      skip
      require "benchmark/ips"
                      # ruby     25.745k (± 1.4%) i/s -    131.172k in   5.096090s

                      # with simpler CI
                      # ruby     25.949k (± 1.6%) i/s -    131.150k in   5.055484s

                      # pass circuit_options as positional
                      # ruby     26.526k (± 2.1%) i/s -    134.283k in   5.064631s

                      # don't use initial_aggregate but pass it directly.
                      # ruby     26.349k (± 0.9%) i/s -    132.250k in   5.019630s

      # require "benchmark/ips"

      activity = activity_for()

      Benchmark.ips do |x|
        x.report("ruby") {
          signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{params: [], }, {}])
        }
      end
    end

    it "filter API, order, naming" do
      activity = activity_for()

      input_pipe = activity.to_h[:config][:wrap_static][Capture].to_a[0][1].instance_variable_get(:@pipe).to_a

      set_variable = input_pipe[0][1]
      assert_equal set_variable.instance_variable_get(:@filter).instance_variable_get(:@variable_name), :params
      assert_equal set_variable.instance_variable_get(:@write_name), :params
      assert_equal set_variable.instance_variable_get(:@name), "In{:params}"

      set_variable = input_pipe[1][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :mode
      assert_equal set_variable.instance_variable_get(:@name), "In{:mode}"

      set_variable = input_pipe[2][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :styles
      assert_equal set_variable.instance_variable_get(:@name), "In{:styles}"

  # {:variable_name} is what we write to ctx
      set_variable = input_pipe[3][1]
      #@ test the VariableFromCtx
      assert_equal set_variable.instance_variable_get(:@filter).instance_variable_get(:@variable_name), :current_user
      assert_equal set_variable.instance_variable_get(:@write_name), :user
      assert_equal set_variable.instance_variable_get(:@name), "In{:current_user>:user}"

      set_variable = input_pipe[4][1]
      assert_equal set_variable.name, "In.add_variables{#{proc_in.object_id}}"

  # Inject
      set_variable = input_pipe[5][1]
      #@ test the VariableFromCtx
      assert_equal set_variable.instance_variable_get(:@filter).instance_variable_get(:@variable_name), :field
      assert_equal set_variable.instance_variable_get(:@write_name), :field
      assert_equal set_variable.instance_variable_get(:@name), "Inject.default{:field}"

      set_variable = input_pipe[6][1]
      #@ test the VariableFromCtx
      assert_equal set_variable.instance_variable_get(:@filter).instance_variable_get(:@variable_name), :key
      assert_equal set_variable.instance_variable_get(:@write_name), :key
      assert_equal set_variable.instance_variable_get(:@name), "Inject{:key}"

  # Out
      output_pipe = activity.to_h[:config][:wrap_static][Capture].to_a[2][1].instance_variable_get(:@pipe).to_a

      set_variable = output_pipe[0][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :result
      assert_equal set_variable.instance_variable_get(:@name), "Out{:result}"

      set_variable = output_pipe[1][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :message
      assert_equal set_variable.instance_variable_get(:@name), "Out{:message}"

      set_variable = output_pipe[2][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :status
      assert_equal set_variable.instance_variable_get(:@name), "Out{:status}"

      set_variable = output_pipe[3][1]
      assert_equal set_variable.instance_variable_get(:@write_name), :error_code
      assert_equal set_variable.instance_variable_get(:@name), "Out{:code>:error_code}"

      set_variable = output_pipe[4][1]
      assert_equal set_variable.name, "Out.add_variables{#{proc_out.object_id}}"
    end
  end
end


class VariableMappingInheritTest < Minitest::Spec
  it "inherit: [:variable_mapping]" do
    class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
      step :write,
        # all filters can see the original ctx:
        Inject() => {time: ->(ctx, **) { 99 }},
        In() => ->(ctx,**) { {current_user: ctx[:current_user]} },
        Out() => {:current_user => :acting_user},
        Out() => [:incoming]

      def write(ctx, current_user:, time:, **)
        ctx[:incoming] = [ctx[:model], current_user, ctx.to_h]
      end
    end

    # puts Trailblazer::Developer::Render::TaskWrap.(Create, id: :write)

    # raise Trailblazer::Activity::Introspect::Graph(Create).find(:write).data.keys.inspect

  #@ Is the taskWrap inherited?
    class Update < Create
    end

    # TODO: allow adding/modifying the inherited settings.
    class Upsert < Update
      step :write, replace: :write,
        inherit: [:variable_mapping],
          In()  => ->(ctx, model:, action:, **) { {model: model} }, # [:model]
          Out() => {:incoming => :output_of_write}, #
          Out(delete: true) => [:incoming] # as this is statically set in the superclass, we have to delete to make it invisible.
    end

    #@ use inherit: [:variable_mapping] but don't add a filter.
    class Upvote < Create
      step :write, replace: :write,
        inherit: [:variable_mapping]

      def write(ctx, time:, current_user:, **)
        ctx[:incoming] = [ctx[:model], current_user, ctx.to_h].inspect
      end
    end

    #@ {inherit: true} is identical to {inherit: [:variable_mapping]} regarding copying filters.
    class UpvoteWithTrue < Create
      step :write_it, replace: :write,
        inherit: true #, id: :write

      def write_it(ctx, time:, current_user:, **)
        ctx[:incoming] = [ctx[:model], "xxx #{current_user}", ctx.to_h].inspect
      end
    end

  # Create
    #= we don't see {:model} because Create doesn't have an In() for it.
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Create, [{time: "yesterday", model: Object}, {}])

    assert_equal CU.inspect(ctx), %({:time=>"yesterday", :model=>Object, :acting_user=>nil, :incoming=>[nil, nil, {:time=>"yesterday", :current_user=>nil}]})
    #@ {:time} is defaulted by Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Create, [{}, {}])
    assert_equal CU.inspect(ctx), %{{:acting_user=>nil, :incoming=>[nil, nil, {:time=>99, :current_user=>nil}]}}

  # Update and Create work identically
    #= we don't see {:model} because Create doesn't have an In() for it.
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Update, [{time: "yesterday", model: Object}, {}])
    assert_equal CU.inspect(ctx), %({:time=>"yesterday", :model=>Object, :acting_user=>nil, :incoming=>[nil, nil, {:time=>"yesterday", :current_user=>nil}]})

    #@ {:time} is defaulted by Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Update, [{}, {}])
    assert_equal CU.inspect(ctx), %({:acting_user=>nil, :incoming=>[nil, nil, {:time=>99, :current_user=>nil}]})

  #= Upsert additionally sees {:model}
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Upsert, [{time: "yesterday", model: Object, action: :upsert}, {}])
    assert_equal CU.inspect(ctx), %({:time=>"yesterday", :model=>Object, :action=>:upsert, :acting_user=>nil, :output_of_write=>[Object, nil, {:time=>"yesterday", :current_user=>nil, :model=>Object}]})

    #@ {:time} is defaulted by Inject()
    signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Upsert, [{model: Object, action: :upsert}, {}])
    assert_equal CU.inspect(ctx), %({:model=>Object, :action=>:upsert, :acting_user=>nil, :output_of_write=>[Object, nil, {:time=>99, :current_user=>nil, :model=>Object}]})

  #@ inherit works without adding filters
    assert_invoke Upvote, expected_ctx_variables: {:acting_user=>nil, :incoming=>"[nil, nil, #{{:time=>99, :current_user=>nil}}]"}
    assert_invoke Upvote, current_user: Object, expected_ctx_variables: {:acting_user=>Object, :incoming=>"[nil, Object, #{{:time=>99, :current_user=>Object}}]"}

  #@ inherit works with {true}
    assert_invoke UpvoteWithTrue, expected_ctx_variables: {:acting_user=>nil, :incoming=>"[nil, \"xxx \", #{{:time=>99, :current_user=>nil}}]"}
    assert_invoke UpvoteWithTrue, current_user: Object, expected_ctx_variables: {:acting_user=>Object, :incoming=>"[nil, \"xxx Object\", #{{:time=>99, :current_user=>Object}}]"}
  end
end
