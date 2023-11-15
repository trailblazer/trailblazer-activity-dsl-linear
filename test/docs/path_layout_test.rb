require "test_helper"

class ActivityPath_DocsTest < Minitest::Spec
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
      Memo = ActivityPath_DocsTest::Memo
      #:step
      module Memo::Activity
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
      end
      #:step end
    end

    ctx = {params: {text: "Hydrate!"}}

    signal, (ctx, flow_options) = A::Memo::Activity::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}}}
  end

  it do
    module B
      #:validate
      class Create < Trailblazer::Activity::Path
        #~flow
        step :validate, Output(Trailblazer::Activity::Left, :failure) => End(:invalid)
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
    signal, (ctx, _flow_options) = B::Create.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:text=>\"Hydrate!\"}, :input=>{:text=>\"Hydrate!\"}}}

    ctx = {params: nil}
    signal, (ctx, _flow_options) = B::Create.([ctx, {}])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:invalid>}
    _(ctx.inspect).must_equal %{{:params=>nil, :input=>nil}}
=begin
    #:validate-call
    ctx = {params: nil}
    signal, (ctx, flow_options) = Memo::Create.([ctx, {}])

    puts signal #=> #<Trailblazer::Activity::End semantic=:invalid>
    #:validate-call end
=end
  end
end
