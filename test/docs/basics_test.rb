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

    end
    #:render
    Trailblazer::Developer.render(A::Upsert)
    #:render end

    #:upsert-call
    ctx = {id: 1, params: {text: "Hydrate!"}}

    signal, (ctx, flow_options) = A::Upsert.([ctx, {}])
    #:upsert-call end

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx[:memo].inspect).must_equal %{#<struct DocsBasicTest::A::Memo id=1, text=\"Hydrate!\">}

    ctx = {id: 0, params: {text: "Hydrate!"}}

    signal, (ctx, flow_options) = A::Upsert.([ctx, {}])

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx[:memo].inspect).must_equal %{#<struct DocsBasicTest::A::Memo id=nil, text=\"Hydrate!\">}
  end

# Output()
  it "Output()" do
    module B
      #:pay-implicit
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider
        step :charge_creditcard
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-implicit end
    end

    module A
      #:pay-explicit
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider,
          Output(Trailblazer::Activity::Left, :failure) => Track(:failure),
          Output(Trailblazer::Activity::Right, :success) => Track(:success)
        step :charge_creditcard
        #~flow end
        #~mod

        #~mod end
      end
      #:pay-explicit end
    end

    module C
      #:pay-nosignal
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider, Output(:failure) => Track(:failure)
        step :charge_creditcard
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-nosignal end
    end

    _(Trailblazer::Developer.render(A::Execute)).must_equal Trailblazer::Developer.render(B::Execute)
    _(Trailblazer::Developer.render(B::Execute)).must_equal Trailblazer::Developer.render(C::Execute)

    module D
      #:pay-add
      class Execute < Trailblazer::Activity::Railway
        UsePaypal = Class.new(Trailblazer::Activity::Signal)

        #~flow
        step :find_provider, Output(UsePaypal, :paypal) => Track(:paypal)
        step :charge_creditcard
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-add end
    end

    _(Trailblazer::Developer.render(D::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {DocsBasicTest::D::Execute::UsePaypal} => #<End/:failure>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    module E
      #:pay-end
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider
        step :charge_creditcard, Output(:failure) => End(:declined)
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-end end
    end

    _(Trailblazer::Developer.render(E::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<End/:declined>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:declined>

#<End/:failure>
}

    module F
      #:pay-endex
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider
        step :charge_creditcard, Output(:failure) => End(:success)
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-endex end
    end

    _(Trailblazer::Developer.render(F::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    module G
      #:pay-id
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider
        step :charge_creditcard, Output(:failure) => Id(:find_provider)
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-id end
    end

    _(Trailblazer::Developer.render(G::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    module H
      #:pay-track
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider, Output(:success) => Track(:failure)
        step :charge_creditcard
        fail :notify
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-track end
    end

    _(Trailblazer::Developer.render(H::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

    module I
      #:pay-magneticto
      class Execute < Trailblazer::Activity::Railway
        #~flow
        step :find_provider, Output(:failure) => Track(:paypal)
        step :charge_creditcard
        step :charge_paypal, magnetic_to: :paypal
        #~flow end
        #~mod
        #~mod end
      end
      #:pay-magneticto end
    end

    _(Trailblazer::Developer.render(I::Execute)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=find_provider>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_paypal>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_creditcard>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=charge_paypal>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  end
end
