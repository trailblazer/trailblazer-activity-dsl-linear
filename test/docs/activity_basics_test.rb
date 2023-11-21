require "test_helper"

module X
  class DocsActivityTest < Minitest::Spec
    it "basic activity" do
      Memo = Struct.new(:options) do
        def save
          true
        end
      end

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

          #:save
          def save(ctx, params:, **)
            memo = Memo.new(params[:memo])
            memo.save

            ctx[:model] = memo # you can write to the {ctx}.
          end
          #:save end

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
      puts signal.to_h[:semantic] #=> :success #!hint puts result.terminus.to_h[:semantic] #=> :success
      #:memo-call end

      #:memo-call-model
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create,
        params: {memo: {text: "Do not forget!"}}
      )

      #~ctx_to_result
      puts ctx[:model] #=> #<Memo id: 1 text: "Do not forget!">
      #:memo-call-model end
      #~ctx_to_result end

      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>) #!hint assert_equal result.terminus.inspect, %(#<Trailblazer::Activity::Railway::End::Success semantic=:success>)
      #~ignore
      assert_equal ctx.inspect, %({:params=>{:memo=>{:text=>\"Do not forget!\"}}, :model=>#<struct X::DocsActivityTest::Memo options={:text=>\"Do not forget!\"}>})

      model = ctx[:model]

      assert_invoke Memo::Activity::Create, seq: "[]", params: {memo: {text: "Do not forget!"}}, expected_ctx_variables: {model: model}
      assert_invoke Memo::Activity::Create, seq: "[:handle_errors]", params: {}, terminus: :failure
      #~ignore end
    end
  end
end
