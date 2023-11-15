require "test_helper"

class DocsStrategyTest < Minitest::Spec
  class Form
    def self.validate(input)
      raise if input == :raise
      input
    end
  end

  Memo = Struct.new(:text) do
    def self.create(options)
      return options if options == false
      new(options)
    end
  end

  it do
    module C
      #:double-end
      class Create < Trailblazer::Activity::Path
        #~flow
        step :validate, Output(Trailblazer::Activity::Left, :failure) => End(:invalid)
        step :create,   Output(Trailblazer::Activity::Left, :failure) => End(:invalid)
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, input:, create:, **)
          create
        end
        #~mod end
      end
      #:double-end end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, _flow_options) = C::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil}
    signal, (ctx, _flow_options) = C::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    _(ctx.inspect).must_equal %{{:params=>nil, :input=>nil}}

    ctx = {params: {}, create: false}
    signal, (ctx, _flow_options) = C::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    _(ctx.inspect).must_equal %{{:params=>{}, :create=>false, :input=>{}}}

    # puts Trailblazer::Developer.render(C::Create)
  end

  class Logger
    def error(*); end
  end


  it do
    module E

      #:railway-wire
      class Create < Trailblazer::Activity::Railway
        #~flow
        step :validate
        fail :log_error
        step :create, Output(:failure) => End(:db_error)
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, input:, create:, **)
          create
        end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
        end
        #~mod end
      end
      #:railway-wire end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, flow_options) = E::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, _flow_options) = E::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    _(ctx.inspect.sub(/0x\w+/, "0x")).must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: {}, create: false}
    signal, (ctx, _flow_options) = E::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:db_error>}
    _(ctx.inspect).must_equal %{{:params=>{}, :create=>false, :input=>{}}}
  end


  it do
    module F

      #:railway-fail
      class Create < Trailblazer::Activity::Railway
        #~flow
        step :validate
        fail :log_error, Output(:success) => Track(:success)
        step :create
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, **)
          ctx[:create] = true
          true
        end

        def fixable?(params)
          params.nil?
        end
        #~flow end

        def log_error(_ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")

          fixable?(params) ? true : false # or Activity::Right : Activity::Left
        end
        #~mod end
      end
      #:railway-fail end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, _flow_options) = F::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new, log_error: true}
    signal, (ctx, _flow_options) = F::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect.sub(/0x\w+/, "0x")).must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :log_error=>true, :input=>nil, :create=>true}}

    ctx = {params: false, logger: Logger.new, log_error: false}
    signal, (ctx, _flow_options) = F::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    _(ctx.inspect.sub(/0x\w+/, "0x")).must_equal %{{:params=>false, :logger=>#<DocsStrategyTest::Logger:0x>, :log_error=>false, :input=>false}}
  end

  it do
    module G

      #:railway-pass
      class Create < Trailblazer::Activity::Railway
        #~flow
        step :validate
        fail :log_error
        pass :create
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(_ctx, create:, **)
          create
        end

        def log_error(_ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
          true
        end
        #~mod end
      end
      #:railway-pass end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, _flow_options) = G::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, _flow_options) = G::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    _(ctx.inspect.sub(/0x\w+/, "0x")).must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: {}, logger: Logger.new, create: false}
    signal, (ctx, _flow_options) = G::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect.sub(/0x\w+/, "0x")).must_equal %{{:params=>{}, :logger=>#<DocsStrategyTest::Logger:0x>, :create=>false, :input=>{}}}
  end

end
