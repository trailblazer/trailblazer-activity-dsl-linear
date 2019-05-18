require "test_helper"

class DocsIOTest < Minitest::Spec
  it "what" do
    user = Object.new.instance_exec { def can?(*); true; end; self }
    class User
      def self.find(*); "bla"; end
    end

    module A
      module Memo; end
      #:io-ary-hash
      class Memo::Create < Trailblazer::Activity::Path
        step :authorize, input: [:params], output: {user: :current_user}
        step :create_model

        #~io-steps
        #:io-auth
        def authorize(ctx, params:, **)
          ctx[:user] = User.find(params[:id])

          if ctx[:user]
            ctx[:result] = "Found a user."
          else
            ctx[:result] = "User unknown."
          end
        end
        #:io-auth end

        def create_model(ctx, current_user:, **)
          #~mod2
          ctx[:model] = current_user
          #~mod2 end
        end
        #~io-steps end
      end
      #:io-ary-hash end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(A::Memo::Create, [{params: {id: 1}}, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:params=>{:id=>1}, :current_user=>\"bla\", :model=>\"bla\"}}
=begin
#:io-call
ctx = {params: {id: 1}}

signal, (ctx, flow_options) = Activity::TaskWrap.invoke(A::Memo::Create, [ctx, {}])

ctx #=> {:params=>{:id=>1}, :current_user=>#<User ..>, :model=>#<Memo ..>}}
#:io-call end
=end
    end
  end
end
