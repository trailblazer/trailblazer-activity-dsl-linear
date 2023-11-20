require "test_helper"

class FastTrack_Layout_Passfast_DocTest < Minitest::Spec
  Memo = Class.new
  it do
    #:ft-passfast
    module Memo::Activity
      class Create < Trailblazer::Activity::FastTrack
        step :validate, pass_fast: true
        step :save
        fail :handle_errors
        #~mod
        include T.def_steps(:validate, :handle_errors, :save)
        #~mod end
      end
    end
    #:ft-passfast end

    assert_invoke Memo::Activity::Create, terminus: :pass_fast, seq: "[:validate]"
    assert_invoke Memo::Activity::Create, validate: false, seq: "[:validate, :handle_errors]", terminus: :failure
  end
end

class FastTrack_Layout_Failfast_DocTest < Minitest::Spec
  Memo = Class.new
  it do
    #:ft-failfast
    module Memo::Activity
      class Create < Trailblazer::Activity::FastTrack
        step :validate, fail_fast: true
        step :save
        fail :handle_errors
        #~mod
        include T.def_steps(:validate, :handle_errors, :save)
        #~mod end
      end
    end
    #:ft-failfast end

    assert_invoke Memo::Activity::Create, terminus: :fail_fast, seq: "[:validate]", validate: false
    assert_invoke Memo::Activity::Create, seq: "[:validate, :save]"
    assert_invoke Memo::Activity::Create, save: false, seq: "[:validate, :save, :handle_errors]", terminus: :failure
  end
end

class FastTrack_Layout_FastTrack_DocTest < Minitest::Spec
  Memo = Class.new
  it do
    #:ft-fasttrack
    class Create < Trailblazer::Activity::FastTrack
      module Memo::Activity
        class Create < Trailblazer::Activity::FastTrack
          step :validate, fast_track: true
          step :save
          fail :handle_errors

          def validate(ctx, params:, **)
            return Trailblazer::Activity::FastTrack::FailFast if params.nil? #!hint return Railway.fail_fast! if params.nil?

            params.key?(:memo)
          end
          #~mod
          include T.def_steps(:validate, :handle_errors, :save)
          #~mod end
        end
      end
    end
    #:ft-fasttrack end


    assert_invoke Memo::Activity::Create, terminus: :fail_fast, seq: "[]", params: nil
    assert_invoke Memo::Activity::Create, seq: "[:save]", params: {memo: nil}
    assert_invoke Memo::Activity::Create, seq: "[:handle_errors]", terminus: :failure, params: {}
  end
end
