require "test_helper"

class DocsIOTest < Minitest::Spec
  class User
    def self.find(id); "User #{id.inspect}"; end
  end

  it "what" do
    user = Object.new.instance_exec { def can?(*); true; end; self }

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
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(A::Memo::Create, [{params: {id: 1}}, {}])
    #:io-call end
    assert_equal %{#<Trailblazer::Activity::End semantic=:success>}, signal.inspect
  ## {:user} is not visible in public ctx due to {:output}.
    assert_equal %{{:params=>{:id=>1}, :current_user=>\"User 1\", :model=>\"User 1\"}}, CU.inspect(ctx)

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

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      assert_equal signal.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

    # {:output} with {inner_ctx, outer_ctx, **} using {:output_with_outer_ctx}
      module F
        class Memo < Trailblazer::Activity::Path
          #:io-outer-kw
          step :authorize,
            output_with_outer_ctx: true, # tell TRB you want {outer_ctx} in the {:output} filter.
            output: ->(inner_ctx, outer_ctx:, user:, **) do
              {
                current_user: user,
                params:       outer_ctx[:params].merge(errors: false)
              }
            end
          #:io-outer-kw end
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
      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(F::Memo, [{params: {id: "1"}}.freeze, {}])
      assert_equal signal.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:params=>{:id=>\"1\", :errors=>false}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      module G
        class Memo < Trailblazer::Activity::Path
          step :authorize, output: :authorize_output, output_with_outer_ctx: true
          step :create_model

          def authorize(ctx, params:, **)
            ctx[:user] = User.find(params[:id])
          end

          def authorize_output(inner_ctx, outer_ctx:, user:, **)
            {
              current_user: user,
              params:       outer_ctx[:params].merge(errors: false)
            }
          end

          def create_model(ctx, current_user:, **)
            ctx[:model] = current_user
          end
        end

      end
      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(F::Memo, [{params: {id: "1"}}.freeze, {}])
      assert_equal signal.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:params=>{:id=>\"1\", :errors=>false}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}



      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::Memo::Bla, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(C::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(D::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :user=>\"User \\\"1\\\"\", :result=>\"Found a user.\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal CU.inspect(ctx), %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}
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

  # inject: [:time, {:date => Inject.Rename(:today)}, {:time => ->(*) { 1 }}, , {:date => [Inject.Rename(:today), ->(*) { 1 }]}]
  # becomes
  # injections: [:time, :date]    # pass-through (and rename) if there
  # injections_with_default: []   # pass-through (and rename) if there, otherwise default
  describe ":inject" do
    it "{inject: [:time]}" do
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
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(G::Create, [{catch_args: [], database: []}, {}])
      assert_equal '{:catch_args=>[[:catch_args, :database], [:db, :catch_args], [:catch_args, :database, :log]], :database=>["persist"], :log=>"Called ', CU.inspect(ctx)[0..131]
                                                              #   {:time} is not visible in {Log}

    # {:time} is injected
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(G::Create, [{catch_args: [], database: [], time: "yesterday"}, {}], **{})
      assert_equal '{:catch_args=>[[:catch_args, :database, :time], [:db, :catch_args, :time], [:catch_args, :database, :time, :log]], :database=>["persist"], :time=>"yesterday", :log=>"Called yesterday!"}', CU.inspect(ctx)
    end # it


    it "still allows aliasing within the inject wrap" do
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

      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(H::Outer, [Trailblazer::Context({"contract.default" => Module}, {}, flow_options[:context_options]), flow_options])
      assert_equal ctx.inspect, %(#<Trailblazer::Context::Container::WithAliases wrapped_options=#{{"contract.default" => Module}} mutable_options=#{{:inner_contract=>Module, :inner_contract_default=>Module}} aliases=#{{:"contract.default" => :contract}}>)
    end

  # inject without input (1)
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

      # we only inject [:pass, :through] variables. This means, nothing special happens,
      # we simply pass the original ctx.
        class Create < Trailblazer::Activity::Railway
          step :model
          step Subprocess(Log), inject: [:time]
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # I

    # inject {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(I::Create, [{catch_args: [], database: [], time: "yesterday"}, {}])
      assert_equal CU.inspect(ctx), %{{:catch_args=>[[:catch_args, :database, :time], [:catch_args, :database, :time], [:catch_args, :database, :time, :log]], :database=>[], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}

    # default {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(I::Create, [{catch_args: [], database: []}, {}])
      assert_equal CU.inspect(ctx)[0..130], '{:catch_args=>[[:catch_args, :database], [:catch_args, :database], [:catch_args, :database, :log]], :database=>[], :log=>"Called 20'
    end

  # inject without input (2)
    it "{inject: [{variable: default}]} (without pass-through variables) will pass all original variables plus the defaulting" do
      module X
        class Log < Trailblazer::Activity::Railway
          step :catch_args # this allows to see whether {:time} is passed in or not.
          step :write

          def write(ctx, time: Time.now, **)
            ctx[:log] = "Called #{time}!"
          end

          def catch_args(ctx, **); Test.catch_args(ctx); end
        end

      # we only use `inject: [{variable: default}]`. No {:input}.
      # this means the "almost original" ctx plus defaulting is passed into {Log}.
        class Create < Trailblazer::Activity::Railway
          step :model
          step Subprocess(Log), inject: [{time: ->(*) { 1 }}] # NO {:input}.
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # X

    # inject {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(X::Create, [{catch_args: [], database: [], time: "yesterday"}, {}])
      assert_equal CU.inspect(ctx), %{{:catch_args=>[[:catch_args, :database, :time], [:catch_args, :database, :time], [:catch_args, :database, :time, :log]], :database=>[], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}

    # default {:time}
    # injected/defaulted variables such as {:time} are NOT visible in the outer context if not configured otherwise.
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(X::Create, [{catch_args: [], database: []}, {}])        # {:time} is "gone", not here anymore!
      assert_equal CU.inspect(ctx), '{:catch_args=>[[:catch_args, :database], [:catch_args, :database, :time], [:catch_args, :database, :log]], :database=>[], :log=>"Called 1!"}'
    end

    it "Inject replacement" do
      skip
      step Model(action: :new) # def Model(action: :new)  / inject: [:action]
      step Model(action: :new), injections: {action: :new} # def Model(action: :new)  / inject: [:action]
    end

    it "allows {:inject} with defaults" do
      module J
        class Log < Trailblazer::Activity::Railway
          step :write

          def write(ctx, time: Time.now, **) # DISCUSS: this defaulting is *never* applied.
            ctx[:log] = "Called #{time}!"
          end
        end

        class Create < Trailblazer::Activity::Railway
          step :model
          # step Subprocess(Log), inject: [:time, :catch_args]
          step Subprocess(Log), inject: [{:time => ->(*) { "tomorrow" }}] # FIXME.
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # J

      # inject {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(J::Create, [{database: [], catch_args: [], time: "yesterday"}, {}])
      assert_equal CU.inspect(ctx), %{{:database=>[], :catch_args=>[[:database, :catch_args, :time], [:database, :catch_args, :time, :log]], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}

    # default {:time} from {:inject}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(J::Create, [{database: [], catch_args: []}, {}])
      assert_equal CU.inspect(ctx), '{:database=>[], :catch_args=>[[:database, :catch_args], [:database, :catch_args, :log]], :log=>"Called tomorrow!"}'


  # test arguments/kw args passed to filter.
      module K
        class Log < Trailblazer::Activity::Railway
          step :write

          def write(ctx, time: Time.now, date:, **) # DISCUSS: this defaulting is *never* applied.
            ctx[:log] = "Called #{time}@#{date}!"
          end
        end

        class Create < Trailblazer::Activity::Railway
          step :model
          # step Subprocess(Log), inject: [:time, :catch_args]
          step Subprocess(Log), inject: [
            {
              time: ->(*) { "tomorrow" },
              date: ->(ctx, ago:, **) { "#{ago} years ago" }
            }
          ]
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # K

      # inject {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(K::Create, [{database: [], catch_args: [], time: "yesterday", ago: 700}, {}])
      assert_equal CU.inspect(ctx), %{{:database=>[], :catch_args=>[[:database, :catch_args, :time, :ago], [:database, :catch_args, :time, :ago, :log]], :time=>\"yesterday\", :ago=>700, :log=>\"Called yesterday@700 years ago!\"}}

    # default {:time} from {:inject}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(K::Create, [{database: [], catch_args: [], ago: 700}, {}])
      assert_equal CU.inspect(ctx), '{:database=>[], :catch_args=>[[:database, :catch_args, :ago], [:database, :catch_args, :ago, :log]], :ago=>700, :log=>"Called tomorrow@700 years ago!"}'
    end

    it "allows inject: [:action, {volume: ->(*) {}}]" do
      module L
        class Log < Trailblazer::Activity::Railway
          step :write

          def write(ctx, time: Time.now, action: :new, volume: 9, **)
            ctx[:log] = "Called #{time}@#{action}@#{volume}!"
          end
        end

        class Create < Trailblazer::Activity::Railway
          step :model
          step Subprocess(Log), inject: [
            :action, :volume, # just pass-through
            {
              time: ->(ctx, **) { "tomorrow" },
            }
          ]
          step :save

          def save(ctx, **);  Test.catch_args(ctx); end
          def model(ctx, **); Test.catch_args(ctx); end
        end
      end # L

      # inject {:volume}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(L::Create, [{database: [], catch_args: [], volume: 99}, {}])
      assert_equal CU.inspect(ctx), %{{:database=>[], :catch_args=>[[:database, :catch_args, :volume], [:database, :catch_args, :volume, :log]], :volume=>99, :log=>"Called tomorrow@new@99!"}}
    end

=begin
    inject: [:action] # simply pass variable :action in (exclusive) {action: ctx[:action]} (IF IT'S PRESENT IN ctx)
  DISCUSS: from here onwards, this is what {:input} kind of does???  this  is defaulting and would happen in any case
    inject: [:action => Static(:new)]     # {action: new}
    inject: [:action => Value(->(*) {})]  # {action: <dynamic value>}
    inject: {:action => [Value(), Rename(:inner_action)]}
    inject: {:action => [:inner_action, Value()]}
=end

    it "inject: [:variable], input: {}" do
      module Y
        class Log < Trailblazer::Activity::Railway # could be Operation, too.
          step :write
          # ...
          def write(ctx, time: Time.now, **)
            ctx[:log] = "Called @ #{time}!"
          end
        end

        #:inject-array
        class Create < Trailblazer::Activity::Railway # could be Operation, too.
          # ...
          step Subprocess(Log),
            input:  ->(ctx, model:, **) { {model: model} }, # always pass {model}
            inject: [:time] # only pass {:time} when it's in ctx.
        end
        #:inject-array end
      end

      Log = Y::Log
      #:inject-log-time
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Log, [{time: "yesterday"}, {}])
      #:inject-log-time end
      assert_equal CU.inspect(ctx), %{{:time=>\"yesterday\", :log=>\"Called @ yesterday!\"}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Log, [{}, {}])
      assert_equal CU.inspect(ctx)[0..18], '{:log=>"Called @ 20'

      module Z
        #:write-defaulted
        class Log < Trailblazer::Activity::Railway # could be Operation, too.
          step :write
          # ...
          def write(ctx, time: Time.now, **) # {:time} is a dependency.
            ctx[:log] = "Called @ #{time}!"
          end
        #:write-defaulted end
        end

        #:clumsy-merge
        class Create < Trailblazer::Activity::Railway # could be Operation, too.
          # ...
          step Subprocess(Log),
            input:  ->(ctx, model:, **) {
              { model: model }                                  # always pass {:model}
              .merge(ctx.key?(:time) ? {time: ctx[:time]} : {}) # only add {:time} when it's there.
            }
        end
        #:clumsy-merge end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Z::Create, [{model: Object, time: "yesterday"}, {}])
      assert_equal CU.inspect(ctx), %{{:model=>Object, :time=>\"yesterday\", :log=>\"Called @ yesterday!\"}}
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Z::Create, [{model: Object, }, {}])
      assert_equal CU.inspect(ctx)[0..33], '{:model=>Object, :log=>"Called @ 2'

      module Q
        #:write-required
        class Log < Trailblazer::Activity::Railway # could be Operation, too.
          step :write
          # ...
          def write(ctx, time: Time.now, date:, **) # {date} has no default configured.
            ctx[:log] = "Called @ #{time} and #{date}!"
          end
        #:write-required end
        end
require "date"
        #:inject-default
        class Create < Trailblazer::Activity::Railway # could be Operation, too.
          # ...
          step Subprocess(Log),
            input:  ->(ctx, model:, **) { {model: model} }, # always pass {model}
            inject: [:time, {date: ->(ctx, **) { Date.today }}]
        end
        #:inject-default end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Q::Create, [{time: "yesterday", model: Object}, {}])
      assert_equal CU.inspect(ctx)[0..68], '{:time=>"yesterday", :model=>Object, :log=>"Called @ yesterday and 20'
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Q::Create, [{model: Object}, {}])
      assert_equal CU.inspect(ctx)[0..33], '{:model=>Object, :log=>"Called @ 2'

    end # it
  end
end

# TODO: remove me with 2.2.
class DeprecatedOutWithOuterCtxTest < Minitest::Spec
  User = DocsIOTest::User

  module Methods
    def authorize(ctx, params:, **)
      ctx[:user] = User.find(params[:id])
      ctx[:user] ? ctx[:result] = "Found a user." : ctx[:result] = "User unknown."
    end

    def create_model(ctx, current_user:, **)
      ctx[:model] = current_user
    end
  end

  it do
    _, warning = capture_io do
      #@ {:output} with {inner_ctx, outer_ctx, **} using {:output_with_outer_ctx}
      # Note that this is deprecated.
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

        include Methods
      end

      assert_invoke Memo, params: {id: "1"}, expected_ctx_variables: {params: {id: "1", errors: false}, :current_user=>%{User "1"}, :model=>%{User "1"}}
    end
    line_number_for_output = __LINE__ - 16 # 618

  #@ deprecation warning!!!
    assert_equal warning.split("\n")[0..1].join("\n"), %{[Trailblazer] #{File.realpath(__FILE__)}:#{line_number_for_output} The positional argument `outer_ctx` is deprecated, please use the `:outer_ctx` keyword argument.
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.}
  end

  #@ deprecation warning with Callable for {:output_with_outer_ctx}
  it do
    _, warning = capture_io do
      class Memo2 < Trailblazer::Activity::Path
        class MyOutput
          def self.call(inner_ctx, outer_ctx, user:, **)
            {
              current_user: user,
              params:       outer_ctx[:params].merge(errors: false)
            }
          end
        end

        step :authorize,
          output_with_outer_ctx: true, # tell TRB you want {outer_ctx} in the {:output} filter.
          output: MyOutput
        step :create_model

        include Methods
      end

      assert_invoke Memo2, params: {id: "1"}, expected_ctx_variables: {params: {id: "1", errors: false}, :current_user=>%{User "1"}, :model=>%{User "1"}}
    end
    line_number_for_output = __LINE__ - 10 # 654

  #@ deprecation warning!!!
    assert_equal warning.split("\n")[0..1].join("\n"), %{[Trailblazer] #{File.realpath(__FILE__)}:#{line_number_for_output} The positional argument `outer_ctx` is deprecated, please use the `:outer_ctx` keyword argument.
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-variable-mapping-deprecation-notes and have a nice day.}
  end

  # TODO: add warning test for {:instance_method}
end

=begin
Model(id_field: :key_id)

def "dynamic_model"(id_field: :key_id)

end


step dynamic_model, inject: [:id_field]
step dynamic_model, inject: [:id_field], input: ->(*) { {id_field: 111} } (override the global "injected" one? does that even work?) (or "remap" like {id_field: :another_field})



step Model(..), inject: ->(*) {
  {
    action: :new,
    "model.class" => Song,
  }
}

step Model(..), input: ->(ctx, params:, **) {
  {
    action: params[:model_action],
    "model.class" => Song,
  }
}



=end
