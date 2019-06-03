require "test_helper"

class DocsBasicTest < Minitest::Spec
  it "what" do
    module A
      class Memo < Struct.new(:id, :text)
        def self.find(id)
          return new(1) if id == 1
        end

        def update(text:)
          self.text = text
        end
      end

      #:upsert
      class Upsert < Trailblazer::Activity::Path
        #~flow
        step :find_model, Output(Activity::Left, :failure) => Id(:create)
        step :update
        step :create, magnetic_to: nil, Output(Activity::Right, :success) => Id(:update)
        #~flow end

        #~mod
        def find_model(ctx, id:, **) # A
          ctx[:memo] = Memo.find(id)
          ctx[:memo] ? Activity::Right : Activity::Left # can be omitted.
        end

        def update(ctx, params:, **) # B
          ctx[:memo].update(params)
          true # can be omitted
        end

        def create(ctx, **)
          ctx[:memo] = Memo.new
        end
        #~mod end
      end
      #:upsert end

      #:render
      puts Trailblazer::Developer.render(Upsert)
      #:render end

      #:upsert-call
      ctx = {id: 1, params: {text: "Hydrate!"}}

      signal, (ctx, flow_options) = Upsert.([ctx, {}])
      #:upsert-call end
=begin
#:upsert-result
puts signal #=> #<Trailblazer::Activity::End semantic=:success>
puts ctx    #=> {memo: #<Memo id=1, text="Hydrate!">, id: 1, ...}
#:upsert-result end
=end

      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx[:memo].inspect.must_equal %{#<struct DocsBasicTest::A::Memo id=1, text=\"Hydrate!\">}

      ctx = {id: 0, params: {text: "Hydrate!"}}

      signal, (ctx, flow_options) = Upsert.([ctx, {}])

      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx[:memo].inspect.must_equal %{#<struct DocsBasicTest::A::Memo id=nil, text=\"Hydrate!\">}
    end
  end
end
