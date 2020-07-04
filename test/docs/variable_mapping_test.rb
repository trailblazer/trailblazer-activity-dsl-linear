require "test_helper"

class DocsIOTest < Minitest::Spec
  it "what" do
    user = Object.new.instance_exec { def can?(*); true; end; self }
    class User
      def self.find(id); "User #{id.inspect}"; end
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
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:params=>{:id=>1}, :current_user=>\"User 1\", :model=>\"User 1\"}}
=begin
#:io-call
ctx = {params: {id: 1}}

signal, (ctx, flow_options) = Activity::TaskWrap.invoke(A::Memo::Create, [ctx, {}])

ctx #=> {:params=>{:id=>1}, :current_user=>#<User ..>, :model=>#<Memo ..>}}
#:io-call end
=end
    end

    module B
      module Memo; end
      #:io-proc
      class Memo::Create < Trailblazer::Activity::Path
        step :authorize,
          input:  ->(original_ctx, **) do {params: original_ctx[:parameters]} end,
          output: ->(scoped_ctx, **) do {current_user: scoped_ctx[:user]} end
        step :create_model

        #~mod
        def authorize(ctx, params:, **)
          ctx[:user] = User.find(params[:id])

          if ctx[:user]
            ctx[:result] = "Found a user."
          else
            ctx[:result] = "User unknown."
          end
        end

        def create_model(ctx, current_user:, **)
          ctx[:model] = current_user
        end
        #~mod end
      end
      #:io-proc end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      class Memo::Bla < Trailblazer::Activity::Path
        #:io-kws
        step :authorize,
          input:  ->(original_ctx, parameters:, **) do {params: parameters} end,
          output: ->(scoped_ctx, user:, **) do {current_user: user} end
        #:io-kws end
        step :create_model

        def authorize(ctx, params:, **)
          ctx[:user] = User.find(params[:id])
          ctx[:user] ? ctx[:result] = "Found a user." : ctx[:result] = "User unknown."
        end

        def create_model(ctx, current_user:, **)
          ctx[:model] = current_user
        end
      end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::Memo::Bla, [{parameters: {id: "1"}}.freeze, {}])
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      module C
        module Memo; end
        #:io-method
        class Memo::Create < Trailblazer::Activity::Path
          step :authorize,
            input:  :authorize_input,
            output: :authorize_output

          def authorize_input(original_ctx, **)
            {params: original_ctx[:parameters]}
          end

          def authorize_output(scoped_ctx, user:, **)
            {current_user: scoped_ctx[:user]}
          end
          #:io-method end
          step :create_model

          def authorize(ctx, params:, **)
            ctx[:user] = User.find(params[:id])
            ctx[:user] ? ctx[:result] = "Found a user." : ctx[:result] = "User unknown."
          end

          def create_model(ctx, current_user:, **)
            ctx[:model] = current_user
          end
        end
      end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(C::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      # no :output, default :output
      module D
        module Memo; end
        #:no-output
        class Memo::Create < Trailblazer::Activity::Path
          step :authorize, input: :authorize_input

          def authorize_input(original_ctx, **)
            {params: original_ctx[:parameters]}
          end

          # def authorize_output(scoped_ctx, user:, **)
          #   {current_user: scoped_ctx[:user]}
          # end
          #:no-output end
          step :create_model

          def authorize(ctx, params:, **)
            ctx[:user] = User.find(params[:id])
            ctx[:user] ? ctx[:result] = "Found a user." : ctx[:result] = "User unknown."
          end

          def create_model(ctx, user:, **)
            ctx[:model] = user
          end
        end
      end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(D::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :user=>\"User \\\"1\\\"\", :result=>\"Found a user.\", :model=>\"User \\\"1\\\"\"}}

      # no :input, default :input
      module E
        module Memo; end
        #:no-input
        class Memo::Create < Trailblazer::Activity::Path
          step :authorize, output: :authorize_output

          def authorize_output(scoped_ctx, user:, **)
            {current_user: scoped_ctx[:user]}
          end
          #:no-input end
          step :create_model

          def authorize(ctx, parameters:, **)
            ctx[:user] = User.find(parameters[:id])
            ctx[:user] ? ctx[:result] = "Found a user." : ctx[:result] = "User unknown."
          end

          def create_model(ctx, current_user:, **)
            ctx[:model] = current_user
          end
        end
      end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      # _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      # _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}
    end
  end
end
