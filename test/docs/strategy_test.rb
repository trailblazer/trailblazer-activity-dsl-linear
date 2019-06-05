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
    module A
      #:step
      class Create < Trailblazer::Activity::Path
        step :validate
        step :create
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params)
        end

        def create(ctx, input:, **)
          Memo.create(input)
        end
        #~mod end
      end
      #:step end
    end

    ctx = {params: {text: "Hydrate!"}}

    signal, (ctx, flow_options) = A::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}}}
  end

  it do
    module B
      #:validate
      class Create < Trailblazer::Activity::Path
        #~flow
        step :validate, Output(Activity::Left, :failure) => End(:invalid)
        step :create
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, input:, **)
          Memo.create(input)
        end
        #~mod end
      end
      #:validate end
    end

    ctx = {params: {text: "Hydrate!"}}
    signal, (ctx, flow_options) = B::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil}
    signal, (ctx, flow_options) = B::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    ctx.inspect.must_equal %{{:params=>nil, :input=>nil}}
=begin
    #:validate-call
    ctx = {params: nil}
    signal, (ctx, flow_options) = Memo::Create.([ctx, {}])

    puts signal #=> #<Trailblazer::Activity::End semantic=:invalid>
    #:validate-call end
=end
  end

  it do
    module C
      #:double-end
      class Create < Trailblazer::Activity::Path
        #~flow
        step :validate, Output(Activity::Left, :failure) => End(:invalid)
        step :create,   Output(Activity::Left, :failure) => End(:invalid)
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
    signal, (ctx, flow_options) = C::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil}
    signal, (ctx, flow_options) = C::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    ctx.inspect.must_equal %{{:params=>nil, :input=>nil}}

    ctx = {params: {}, create: false}
    signal, (ctx, flow_options) = C::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    ctx.inspect.must_equal %{{:params=>{}, :create=>false, :input=>{}}}

    # puts Trailblazer::Developer.render(C::Create)
  end

  class Logger
    def error(*); end
  end

  it do
    module D

      #:railway
      class Create < Trailblazer::Activity::Railway
        #~flow
        step :validate
        fail :log_error
        step :create
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
      #:railway end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, flow_options) = D::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = D::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: {}, create: false}
    signal, (ctx, flow_options) = D::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.must_equal %{{:params=>{}, :create=>false, :input=>{}}}
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

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = E::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: {}, create: false}
    signal, (ctx, flow_options) = E::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:db_error>}
    ctx.inspect.must_equal %{{:params=>{}, :create=>false, :input=>{}}}
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

        def create(ctx, input:, **)
          ctx[:create] = true
          true
        end

        def fixable?(params)
          params.nil?
        end
        #~flow end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")

          fixable?(params) ? true : false # or Activity::Right : Activity::Left
        end
        #~mod end
      end
      #:railway-fail end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, flow_options) = F::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new, log_error: true}
    signal, (ctx, flow_options) = F::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :log_error=>true, :input=>nil, :create=>true}}

    ctx = {params: false, logger: Logger.new, log_error: false}
    signal, (ctx, flow_options) = F::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>false, :logger=>#<DocsStrategyTest::Logger:0x>, :log_error=>false, :input=>false}}
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

        def create(ctx, create:, **)
          create
        end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
          true
        end
        #~mod end
      end
      #:railway-pass end
    end

    ctx = {params: {text: "Hydrate!"}, create: true}
    signal, (ctx, flow_options) = G::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :create=>true, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = G::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: {}, logger: Logger.new, create: false}
    signal, (ctx, flow_options) = G::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>{}, :logger=>#<DocsStrategyTest::Logger:0x>, :create=>false, :input=>{}}}
  end

  it do
    module H

      #:ft-passfast
      class Create < Trailblazer::Activity::FastTrack
        #~flow
        step :validate, pass_fast: true
        fail :log_error
        step :create
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, **)
          ctx[:create] = true
          create
        end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
          true
        end
        #~mod end
      end
      #:ft-passfast end
    end

    ctx = {params: {text: "Hydrate!"}}
    signal, (ctx, flow_options) = H::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:pass_fast>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = H::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}
  end

  it do
    module I

      #:ft-failfast
      class Create < Trailblazer::Activity::FastTrack
        #~flow
        step :validate, fail_fast: true
        fail :log_error
        step :create
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          ctx[:input] = Form.validate(params) # true/false
        end

        def create(ctx, **)
          ctx[:create] = true
        end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
          true
        end
        #~mod end
      end
      #:ft-failfast end
    end

    ctx = {params: {text: "Hydrate!"}}
    signal, (ctx, flow_options) = I::Create.([ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}, :create=>true}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = I::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}
  end

  it do
    module J

      #:ft-fasttrack
      class Create < Trailblazer::Activity::FastTrack
        #~flow
        step :validate, fast_track: true
        fail :log_error
        step :create
        #~flow end
        #~mod
        def validate(ctx, params:, **)
          begin
            ctx[:input] = Form.validate(params) # true/false
          rescue
            return Activity::FastTrack::FailFast # signal
          end

          ctx[:input] # true/false
        end

        def create(ctx, **)
          ctx[:create] = true
        end

        def log_error(ctx, logger:, params:, **)
          logger.error("wrong params: #{params.inspect}")
          true
        end
        #~mod end
      end
      #:ft-fasttrack end
    end

    ctx = {params: {text: "Hydrate!"}}
    signal, (ctx, flow_options) = J::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}, :create=>true}}

    ctx = {params: nil, logger: Logger.new}
    signal, (ctx, flow_options) = J::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx.inspect.sub(/0x\w+/, "0x").must_equal %{{:params=>nil, :logger=>#<DocsStrategyTest::Logger:0x>, :input=>nil}}

    ctx = {params: :raise}
    signal, (ctx, flow_options) = J::Create.([ctx, {}])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx.inspect.must_equal %{{:params=>:raise}}
  end
end
