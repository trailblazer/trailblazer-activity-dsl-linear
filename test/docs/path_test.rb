require "test_helper"

class DocsPathTest < Minitest::Spec
  it do
    module A
      #:path
      class Charge < Trailblazer::Activity::Path
        #~meths
        include T.def_tasks(:a, :b, :c, :d, :e)
        #~meths end
        step :validate
        step :decide_type, Output(Activity::Left, :credit_card) => Path(end_id: "End.cc", end_task: End(:with_cc)) do
          step :authorize
          step :charge
        end
        step :direct_debit
      end
      #:path end
    end

    assert_process_for A::Charge, :with_cc, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Right} => <*direct_debit>
 {Trailblazer::Activity::Left} => <*authorize>
<*authorize>
 {Trailblazer::Activity::Right} => <*charge>
<*charge>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
#<End/:with_cc>

<*direct_debit>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    module B
      #:path-join
      class Charge < Trailblazer::Activity::Path
        #~meths
        include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)
        #~meths end
        step :validate
        step :decide_type, Output(Trailblazer::Activity::Left, :credit_card) => Path(connect_to: Id(:finalize)) do
          step :authorize
          step :charge
        end
        step :direct_debit
        step :finalize
      end
      #:path-join end
    end

    assert_process_for B::Charge, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Right} => <*direct_debit>
 {Trailblazer::Activity::Left} => <*authorize>
<*authorize>
 {Trailblazer::Activity::Right} => <*charge>
<*charge>
 {Trailblazer::Activity::Right} => <*finalize>
<*direct_debit>
 {Trailblazer::Activity::Right} => <*finalize>
<*finalize>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    ctx = {seq: []}

    signal, (ctx, flow_options) = B::Charge.([ctx, {}])
    ctx.inspect.must_equal %{{:seq=>[:validate, :decide_type, :direct_debit, :finalize]}}

    signal, (ctx, flow_options) = B::Charge.([{seq: [], decide_type: false}, {}])
    ctx.inspect.must_equal %{{:seq=>[:validate, :decide_type, :authorize, :charge, :finalize], :decide_type=>false}}
  end

  it "works in Railway" do
    module C
      CreditCard = Class.new
      DebitCard  = Class.new

      #:path-railway
      class Charge < Trailblazer::Activity::Railway
        MySignal = Class.new(Trailblazer::Activity::Signal)
        #~meths
        include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)
        #:path-decider
        def decide_type(ctx, model:, **)
          if model.is_a?(CreditCard)
            return MySignal # go the Path() way!
          elsif model.is_a?(DebitCard)
            return true
          else
            return false
          end
        end
        #:path-decider end
        #~meths end
        step :validate
        step :decide_type, Output(MySignal, :credit_card) => Path(connect_to: Id(:finalize)) do
          step :authorize
          step :charge
        end
        step :direct_debit
        step :finalize
      end
      #:path-railway end
    end

    assert_process_for C::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*direct_debit>
 {DocsPathTest::C::Charge::MySignal} => <*authorize>
<*authorize>
 {Trailblazer::Activity::Right} => <*charge>
<*charge>
 {Trailblazer::Activity::Right} => <*finalize>
<*direct_debit>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*finalize>
<*finalize>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    signal, (ctx, flow_options) = C::Charge.([{seq: [], model: C::DebitCard.new}, {}])
    ctx.inspect.gsub(/0x\w+/, "").must_equal %{{:seq=>[:validate, :direct_debit, :finalize], :model=>#<DocsPathTest::C::DebitCard:>}}

    signal, (ctx, flow_options) = C::Charge.([{seq: [], model: C::CreditCard.new}, {}])
    ctx.inspect.gsub(/0x\w+/, "").must_equal %{{:seq=>[:validate, :authorize, :charge, :finalize], :model=>#<DocsPathTest::C::CreditCard:>}}

    signal, (ctx, flow_options) = C::Charge.([{seq: [], model: nil}, {}])
    ctx.inspect.gsub(/0x\w+/, "").must_equal %{{:seq=>[:validate], :model=>nil}}
  end

  it "allows multiple Path()s per step" do
    module D
      class Charge < Trailblazer::Activity::Railway
        include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)

        failure_path = ->(*) { step :go }
        success_path = ->(*) { step :surf }

        step :validate
        step :decide_type,
          Output(:failure) => Path(connect_to: Id(:finalize), &failure_path),
          Output(:success) => Path(connect_to: Id(:finalize), &success_path)
        step :direct_debit
        step :finalize
      end
      #:path-railway end
    end

    assert_process_for D::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => <*go>
 {Trailblazer::Activity::Right} => <*surf>
<*go>
 {Trailblazer::Activity::Right} => <*finalize>
<*surf>
 {Trailblazer::Activity::Right} => <*finalize>
<*direct_debit>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*finalize>
<*finalize>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end
end
