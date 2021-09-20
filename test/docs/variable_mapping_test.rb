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
    end
    #:io-call
    signal, (ctx, flow_options) = Activity::TaskWrap.invoke(A::Memo::Create, [{params: {id: 1}}, {}])
    #:io-call end
    assert_equal %{#<Trailblazer::Activity::End semantic=:success>}, signal.inspect
    assert_equal %{{:params=>{:id=>1}, :current_user=>\"User 1\", :model=>\"User 1\"}}, ctx.inspect

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
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

    # {:output} with {inner_ctx, outer_ctx, **} using {:output_with_outer_ctx}
      module F
        class Memo < Trailblazer::Activity::Path
          #:io-output-positionals
          step :authorize,
            output_with_outer_ctx: true, # tell TRB you want {outer_ctx} in the {:output} filter.
            output: ->(inner_ctx, outer_ctx, user:, **) do
              {
                current_user: user,
                params:       outer_ctx[:params].merge(errors: false)
              }
            end
          #:io-output-positionals end
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

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(F::Memo, [{params: {id: "1"}}.freeze, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:params=>{:id=>\"1\", :errors=>false}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}
    end

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::Memo::Bla, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::C::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::D::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :user=>\"User \\\"1\\\"\", :result=>\"Found a user.\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(B::E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}
  end

    # step Subprocess(Auth::Activity::CreateKey),
  #   input: ->(ctx, user:, **) {
  #   {key_model_class: VerifyAccountKey, user: user}.
  #   merge(ctx.to_h.slice(:secure_random))
  #   },

  module Test
    def self.catch_args(ctx, catch_args: [], **)
      ctx[:catch_args] << ctx.keys
    end
  end

  describe ":inject" do
    it "what" do
      module G
        class Log < Trailblazer::Activity::Railway
          step :catch_args # this allows to see whether {:time} is passed in or not.
          step :write
          step :persist

          def write(ctx, time: Time.now, **)
            ctx[:log] = "Called #{time}!"
          end

          # to test if the explicit {:input} filter works.
          def persist(ctx, db:, **)
            db << "persist"
          end

          def catch_args(ctx, **); Test.catch_args(ctx); end
        end

        class Create < Trailblazer::Activity::Railway
          step :model
          # step Subprocess(Log), inject: :time # TODO

          step Subprocess(Log),
            inject: [:time],
            input: ->(ctx, database:, **) { {db: database, catch_args: ctx[:catch_args]} }#, # TODO: test if we can access :time here
          # step Subprocess(Log), inject: :time, input: ->(ctx, **) do
          #   if ctx.keys?(:time)
          #     {time:  ctx[:time]}  # this we want to avoid.
          #   else
          #     {}
          #   end
          # end

          step :save

          def model(ctx, **); Test.catch_args(ctx); end
          def save(ctx, **);  Test.catch_args(ctx); end
        end

      end # G

    # {:time} is defaulted
      _, (ctx, _) = Activity::TaskWrap.invoke(G::Create, [{catch_args: [], database: []}, {}])
      assert_equal '{:catch_args=>[[:catch_args, :database], [:db, :catch_args], [:catch_args, :database, :log]], :database=>["persist"], :log=>"Called ', ctx.inspect[0..131]
                                                              #   {:time} is not visible in {Log}

    # {:time} is injected
      _, (ctx, _) = Activity::TaskWrap.invoke(G::Create, [{catch_args: [], database: [], time: "yesterday"}, {}], **{})
      assert_equal '{:catch_args=>[[:catch_args, :database, :time], [:db, :catch_args, :time], [:catch_args, :database, :time, :log]], :database=>["persist"], :time=>"yesterday", :log=>"Called yesterday!"}', ctx.inspect#[0..65]
    end # it


    it "still allows aliasing" do
      module H
        class Inner < Trailblazer::Activity::Railway
          step :contract
          step :contract_default

          # we use {:contract} alias here
          def contract(ctx, contract:, **); ctx[:inner_contract] = contract; end
          def contract_default(ctx, **); ctx[:inner_contract_default] = ctx["contract.default"]; end
        end

        class Outer < Trailblazer::Activity::Railway
          step Subprocess(Inner),
            input: ->(ctx,  contract:, **) { {"contract.default" => contract} },
            inject: [:model] # not used.
        end
      end

      flow_options = {
        context_options: {
          aliases: {'contract.default': :contract},
          container_class: Trailblazer::Context::Container::WithAliases,
        }
      }

      _, (ctx, _) = Activity::TaskWrap.invoke(H::Outer, [Trailblazer::Context({"contract.default" => Module}, {}, flow_options[:context_options]), flow_options])
      assert_equal %{#<Trailblazer::Context::Container::WithAliases wrapped_options={\"contract.default\"=>Module} mutable_options={:inner_contract=>Module, :inner_contract_default=>Module} aliases={:\"contract.default\"=>:contract}>}, ctx.inspect
    end

    it "allows {:inject} without {:input}" do
      module I
        class Log < Trailblazer::Activity::Railway
          step :catch_args # this allows to see whether {:time} is passed in or not.
          step :write

          def write(ctx, time: Time.now, **)
            ctx[:log] = "Called #{time}!"
          end

          def catch_args(ctx, **); Test.catch_args(ctx); end
        end

        class Create < Trailblazer::Activity::Railway
          step :model
          step Subprocess(Log), inject: [:time, :catch_args]
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # I

    # inject {:time}
      _, (ctx, _) = Activity::TaskWrap.invoke(I::Create, [{catch_args: [], database: [], time: "yesterday"}, {}])
      assert_equal %{{:catch_args=>[[:catch_args, :database, :time], [:time, :catch_args], [:catch_args, :database, :time, :log]], :database=>[], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}, ctx.inspect

    # default {:time}
      _, (ctx, _) = Activity::TaskWrap.invoke(I::Create, [{catch_args: [], database: []}, {}])
      assert_equal '{:catch_args=>[[:catch_args, :database], [:catch_args], [:catch_args, :database, :log]], :database=>[], :log=>"Called 20', ctx.inspect[0..119]
    end



    # TODO: test if injections are discarded afterwards
    # TODO: can we use Context() from VariableMapping?
    # TODO: :inject, only.
    # TODO: inject: {"action.class" => Song}

    # input:, inject:
    #   input.()
    #     inject.() # take all variables from input's ctx + injected
    #     inject-out.() (just return input's ctx variables WITHOUT injected PLUS mutable?)
    #   output.()
  end
end

=begin
Model(id_field: :key_id)

def "dynamic_model"(id_field: :key_id)

end


step dynamic_model, inject: [:id_field]
step dynamic_model, inject: [:id_field], input: ->(*) { {id_field: 111} } (override the global "injected" one? does that even work?) (or "remap" like {id_field: :another_field})

=end
