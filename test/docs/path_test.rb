require "test_helper"

class DocsPathTest < Minitest::Spec
  it do
    module A
      class Charge < Trailblazer::Activity::Path
        extend T.def_tasks(:a, :b, :c, :d, :e)

        out = self

        step :validate
        step :decide_type, Output(Trailblazer::Activity::Left, :credit_card) => Path(end_id: "End.cc", end_task: End(:with_cc)) do
          step :authorize
          step :charge
        end
        step :direct_debit
      end
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
      class Charge < Trailblazer::Activity::Path
        include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)

        step :validate
        step :decide_type, Output(Trailblazer::Activity::Left, :credit_card) => Path(connect_to: Id(:finalize)) do
          step :authorize
          step :charge
        end
        step :direct_debit
        step :finalize
      end
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
end
