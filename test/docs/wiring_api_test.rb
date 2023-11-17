require "test_helper"

#@ original Memo::Activity::Create
class Vanilla_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step :save
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
    end
  end
end

#@ Output => End
class Output_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step :save,
        Output(:failure) => End(:db_error)
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
    end
  end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save]", save: false, terminus: :db_error
  end
end

#@ Output => End
class OutputOnLeft_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step :save
      left :fix_errors,
        Output(:success) => Track(:success)
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :fix_errors, :notify)
    end
  end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :fix_errors, :notify]", save: false
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :fix_errors]", save: false, fix_errors: false, terminus: :failure
  end
end

#@ Output => Track
class OutputToSuccess_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:output-track
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step :save,
        Output(:failure) => Track(:success)
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
      #~meths end
    end
  end
  #:output-track end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]", save: false
  end
end

#@ Output(semantic, Signal) => Track
class ExplicitOutput_WiringApiDocsTest < Minitest::Spec
  Memo = Struct.new(:save_result) do
    def save; self.save_result;  end
  end

  #:output-explicit
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      class DbError < Trailblazer::Activity::Signal; end

      step :validate
      step :save,
        Output(DbError, :database_error) => Track(:failure)
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :handle_errors, :notify)
      def save(ctx, model:, **)
        #~code
        database_broken = ctx[:database_broken]
        #~code end
        return DbError if database_broken

        model.save
      end
      #~meths end
    end
  end
  #:output-explicit end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :handle_errors]", validate: false, terminus: :failure
    assert_invoke Memo::Activity::Create, seq: "[:validate, :notify]", model: Memo.new(true)
    assert_invoke Memo::Activity::Create, seq: "[:validate, :handle_errors]", model: Memo.new(false), terminus: :failure
    assert_invoke Memo::Activity::Create, seq: "[:validate, :handle_errors]", model: Memo.new(true), database_broken: true, terminus: :failure
  end
end

class WiringApiDocsTest < Minitest::Spec
# {#terminus} 1.0
  module A
    class Payment
      module Operation
      end
    end

    #:terminus
    module Payment::Operation
      class Create < Trailblazer::Activity::Railway
        step :find_provider

        terminus :provider_invalid # , id: "End.provider_invalid", magnetic_to: :provider_invalid
        #~meths
        include T.def_steps(:find_provider)
        #~meths end
      end
    end
    #:terminus end
    # @diagram wiring-terminus
  end

  #@ we cannot route to {End.provider_invalid}
  it { assert_invoke A::Payment::Operation::Create, seq: "[:find_provider]" }
  it { assert_invoke A::Payment::Operation::Create, find_provider: false, seq: "[:find_provider]", terminus: :failure }

# {#terminus} 1.1
  module B
    class Payment
      module Operation
      end
    end

    #:terminus-track
    module Payment::Operation
      class Create < Trailblazer::Activity::Railway
        step :find_provider,
          # connect {failure} to the next element that is magnetic_to {:provider_invalid}.
          Output(:failure) => Track(:provider_invalid)

        terminus :provider_invalid
        #~meths
        include T.def_steps(:find_provider)
        #~meths end
      end
    end
    #:terminus-track end
  end

  #@ failure routes to {End.provider_invalid}
  it { assert_invoke B::Payment::Operation::Create, seq: "[:find_provider]" }
  it { assert_invoke B::Payment::Operation::Create, find_provider: false, seq: "[:find_provider]", terminus: :provider_invalid }

  it do
    signal, (ctx, _) = Trailblazer::Activity.(B::Payment::Operation::Create, find_provider: false, seq: [])
    assert_equal signal.to_h[:semantic], :provider_invalid
=begin
    #:terminus-invalid
    signal, (ctx, _) = Payment::Operation::Create.(provider: "bla-unknown")
    puts signal.to_h[:semantic] #=> :provider_invalid
    #:terminus-invalid end
=end

  end
end

#@ :magnetic_to
module A
  class MagneticTo_DocsTest < Minitest::Spec
    Memo = Class.new
    #:magnetic_to
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        step :payment_provider, Output(:failure) => Track(:paypal)
        step :charge_paypal, magnetic_to: :paypal
        step :save
      end
    end
    #:magnetic_to end

    it "what" do
#~ignore
      assert_process Memo::Activity::Create, :success, :failure,  %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*payment_provider>
<*payment_provider>
 {Trailblazer::Activity::Left} => <*charge_paypal>
 {Trailblazer::Activity::Right} => <*save>
<*charge_paypal>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
#~ignore end
    end

  end
end
