require "test_helper"

module X
  class DocsActivityTest < Minitest::Spec
    it "basic activity" do
      Memo = Class.new

      #:memo-create
      module Memo::Activity
        class Create < Trailblazer::Activity::Railway
          step :validate
          #~body
          step :save
          left :handle_errors
          step :notify
          #~meths
          include T.def_steps(:validate, :save, :handle_errors, :notify)

          def save(ctx, **)
            true
          end

          def notify(ctx, **)
            true
          end

          #~body end
          def validate(ctx, params:, **) # home-made validation
            params.key?(:memo) &&
            params[:memo].key?(:text) &&
            params[:memo][:text].size > 9
            # return value matters!
          end
          #~meths end
        end
      end
      #:memo-create end

      #:memo-call
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create,
        params: {memo: {text: "Do not forget!"}}
      )

      puts signal #=> #<Trailblazer::Activity::End semantic=:success>
      puts signal.to_h[:semantic] #=> :success
      #:memo-call end

      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)

      assert_invoke Memo::Activity::Create, seq: "[]", params: {memo: {text: "do not forget!"}}
      assert_invoke Memo::Activity::Create, seq: "[:handle_errors]", params: {}, terminus: :failure
    end
  end
end
