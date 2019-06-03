require "test_helper"

class DocsStrategyTest < Minitest::Spec
  class Form
    def self.validate(input)
      input
    end
  end

  Memo = Struct.new(:text) do
    def self.create(options)
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
end
