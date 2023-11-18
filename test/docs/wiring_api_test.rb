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

  it "what" do
=begin
#:render
puts Trailblazer::Developer.render(Memo::Activity::Create)

#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=validate>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=validate>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_errors>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=save>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_errors>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_errors>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
#:render end
=end
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

#@ Output => Id
class OutputToId_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:output-id
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate,
        Output(:failure) => Id(:notify)
      step :save
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
      #~meths end
    end
  end
  #:output-id end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :notify]", validate: false
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

#@ Output => End
class OutputToEnd_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:output-end
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step :save,
        Output(:failure) => End(:db_error)
      left :handle_errors
      step :notify
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
      #~meths end
    end
  end
  #:output-end end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save]", save: false, terminus: :db_error
  end
end

#@ #terminus
class Terminus_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:terminus
  module Memo::Activity
    class CRUD < Trailblazer::Activity::Railway
      step :validate
      step :save
      terminus :db_error
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
      #~meths end
    end
  end
  #:terminus end

  #:terminus-sub
  module Memo::Activity
    class Create < CRUD
      step :notify,
        Output(:failure) => End(:db_error)
      #~meths
      include T.def_steps(:validate, :save, :handle_errors, :notify)
      #~meths end
    end
  end
  #:terminus-sub end

  it "what" do
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]"
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save]", save: false, terminus: :failure
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save, :notify]", notify: false, terminus: :db_error
  end
end

#@ Track()
class Track_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:custom-track
  module Memo::Activity
    class Charge < Trailblazer::Activity::Railway
      terminus :paypal # add a custom terminus (if you need it)
      step :validate
      step :find_provider,
        Output(:failure) => Track(:paypal)
      step :charge_paypal,
        magnetic_to: :paypal, Output(:success) => Track(:paypal)
      step :charge_default
      #~meths
      include T.def_steps(:validate, :find_provider, :charge_paypal, :charge_default)
      #~meths end
    end
  end
  #:custom-track end

  it "what" do
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_default]"
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, terminus: :paypal
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, charge_paypal: false, terminus: :failure
  end
end

#@ Path()
class Path_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:path-helper
  module Memo::Activity
    class Charge < Trailblazer::Activity::Railway
      step :validate
      step :find_provider,
        Output(:failure) => Path(terminus: :paypal) do
          # step :authorize # you can have multiple steps on a path.
          step :charge_paypal
        end
      step :charge_default
      #~meths
      include T.def_steps(:validate, :find_provider, :charge_paypal, :charge_default)
      #~meths end
    end
  end
  #:path-helper end

  it "what" do
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_default]"
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, terminus: :paypal
    # TODO: this doesn't add a {failure} output.
    # assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, charge_paypal: false, terminus: :failure
  end
end

#@ Path() with error handling: Output()
# class Path_WiringApiDocsTest < Minitest::Spec
#   Memo = Class.new
#   #:path-helper-failure
#   module Memo::Activity
#     class Charge < Trailblazer::Activity::Railway
#       step :validate
#       step :find_provider,
#         Output(:failure) => Path(terminus: :paypal) do
#           step :charge_paypal, Output(:failure) => Track(:failure) # route to the "global" failure track.
#         end
#       step :charge_default

#       #~meths
#       include T.def_steps(:validate, :find_provider, :charge_paypal, :charge_default)
#       #~meths end
#     end
#   end
#   #:path-helper-failure end

#   it "what" do
#     assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_default]"
#     assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, terminus: :paypal
#     assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, charge_paypal: false, terminus: :failure
#   end
# end

#@ Path(:connect_to)
class PathConnectTo_WiringApiDocsTest < Minitest::Spec
  Memo = Class.new
  #:path-helper-connect-to
  module Memo::Activity
    class Charge < Trailblazer::Activity::Railway
      step :validate
      step :find_provider,
        Output(:failure) => Path(connect_to: Id(:finalize)) do
          # step :authorize # you can have multiple steps on a path.
          step :charge_paypal
        end
      step :charge_default
      step :finalize
      #~meths
      include T.def_steps(:validate, :find_provider, :charge_paypal, :charge_default, :finalize)
      #~meths end
    end
  end
  #:path-helper-connect-to end

  it "what" do
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_default, :finalize]"
    assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal, :finalize]", find_provider: false
    # TODO: this doesn't add a {failure} output.
    # assert_invoke Memo::Activity::Charge, seq: "[:validate, :find_provider, :charge_paypal]", find_provider: false, charge_paypal: false, terminus: :failure
  end
end

class WiringApiDocsTest < Minitest::Spec
# {#terminus} 1.0
  module A
    class Payment
      module Operation
      end
    end

    #:terminus-
    module Payment::Operation
      class Create < Trailblazer::Activity::Railway
        step :find_provider

        terminus :provider_invalid # , id: "End.provider_invalid", magnetic_to: :provider_invalid
        #~meths
        include T.def_steps(:find_provider)
        #~meths end
      end
    end
    #:terminus- end
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
