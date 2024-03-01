require "test_helper"

class DocsPathTest < Minitest::Spec
  it do
    module A
      module Song
      end

      #:path
      module Song::Activity
        class Charge < Trailblazer::Activity::Railway
          #~meths
          include T.def_tasks(:a, :b, :c, :d, :e)
          #~meths end
          step :validate
          step :decide_type, Output(:failure) => Path(terminus: :with_cc) do
            step :authorize
            step :charge
          end
          step :direct_debit
        end
      end
      #:path end
    end

    assert_process_for A::Song::Activity::Charge, :success, :with_cc, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => <*authorize>
 {Trailblazer::Activity::Right} => <*direct_debit>
<*authorize>
 {Trailblazer::Activity::Right} => <*charge>
<*charge>
 {Trailblazer::Activity::Right} => #<End/:with_cc>
<*direct_debit>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:with_cc>

#<End/:failure>
}

    module B
      module Song
      end

      #:path-join
      module Song::Activity
        class Charge < Trailblazer::Activity::Railway
          #~meths
          include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)
          #~meths end
          step :validate
          step :decide_type, Output(:failure) => Path(connect_to: Id(:finalize)) do
            step :authorize
            step :charge
          end
          step :direct_debit
          step :finalize
        end
      end
      #:path-join end
    end

    assert_process_for B::Song::Activity::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => <*authorize>
 {Trailblazer::Activity::Right} => <*direct_debit>
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

    assert_invoke B::Song::Activity::Charge, seq: "[:validate, :decide_type, :direct_debit, :finalize]"

    assert_invoke B::Song::Activity::Charge, decide_type: false, seq: "[:validate, :decide_type, :authorize, :charge, :finalize]"
  end

  it "works in Railway" do
    module C
      module Song
      end
      CreditCard = Class.new
      DebitCard  = Class.new

      #:path-railway
      module Song::Activity
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
      end
      #:path-railway end
    end

    assert_process_for C::Song::Activity::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*direct_debit>
 {DocsPathTest::C::Song::Activity::Charge::MySignal} => <*authorize>
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

    assert_invoke C::Song::Activity::Charge, model: C::DebitCard.new, seq: "[:validate, :direct_debit, :finalize]"

    assert_invoke C::Song::Activity::Charge, model: C::CreditCard.new, seq: "[:validate, :authorize, :charge, :finalize]"

    assert_invoke C::Song::Activity::Charge, model: nil, seq: "[:validate]", terminus: :failure
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

  it "Path() => Track(:success) will connect the path's end to a track" do
    module E
      class Charge < Trailblazer::Activity::Railway
        include T.def_steps(:validate, :decide_type, :direct_debit, :finalize, :authorize, :charge)

        step :validate
        step :decide_type,
          Output(:failure) => Path(connect_to: Track(:success)) do
            step :go
          end
        step :direct_debit
        step :finalize
      end

    # Insert step just after the path joins.
      class Overcharge < Charge
        step :overcharge, before: :direct_debit # we want {go --> overcharge --> direct_debit}
      end
    end

    assert_process_for E::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => <*go>
 {Trailblazer::Activity::Right} => <*direct_debit>
<*go>
 {Trailblazer::Activity::Right} => <*direct_debit>
<*direct_debit>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*finalize>
<*finalize>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_process_for E::Overcharge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*decide_type>
<*decide_type>
 {Trailblazer::Activity::Left} => <*go>
 {Trailblazer::Activity::Right} => <*overcharge>
<*go>
 {Trailblazer::Activity::Right} => <*overcharge>
<*overcharge>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*direct_debit>
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

  it "{Path() ..., before: :element} will add all path steps {before}" do
    module F
      class Charge < Trailblazer::Activity::Railway
        step :b
        step :f
        step :a, before: :b, # note the {:before}
          Output(:failure) => Path(connect_to: Track(:success), before: :b) do
            step :c
            step :d # {d} must go into {f}
          end
      end
    end

    assert_process_for F::Charge, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => <*c>
 {Trailblazer::Activity::Right} => <*b>
<*c>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end
end

class DocsPathWithRailwayOptionTest < Minitest::Spec
  Memo = Class.new

  module Memo::Activity
    class Attach < Trailblazer::Activity::Railway
      step :upload_exists?,
        Output(:failure) => Path(connect_to: Track(:success)) do
          step :aws_signin,
            Output(Trailblazer::Activity::Left, :failure) => Track(:failure)
          step :upload,
            Output(Trailblazer::Activity::Left, :failure) => Track(:failure) # FIXME: this configuration gets lost.
        end
    end
  end

  it "we can explicitly connect {:failure} outputs in a Path(), even the last one" do
    assert_process_for Memo::Activity::Attach, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*upload_exists?>
<*upload_exists?>
 {Trailblazer::Activity::Left} => <*aws_signin>
 {Trailblazer::Activity::Right} => #<End/:success>
<*aws_signin>
 {Trailblazer::Activity::Right} => <*upload>
 {Trailblazer::Activity::Left} => #<End/:failure>
<*upload>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
)
  end
end

# TODO: add {Path(railway: true)}
