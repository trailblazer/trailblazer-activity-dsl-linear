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
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(A::Memo::Create, [{params: {id: 1}}, {}])
    #:io-call end
    assert_equal %{#<Trailblazer::Activity::End semantic=:success>}, signal.inspect
  ## {:user} is not visible in public ctx due to {:output}.
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

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
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

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(F::Memo, [{params: {id: "1"}}.freeze, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:params=>{:id=>\"1\", :errors=>false}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}
    end

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::Memo::Bla, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::C::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :current_user=>\"User \\\"1\\\"\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::D::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
      _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      _(ctx.inspect).must_equal %{{:parameters=>{:id=>\"1\"}, :user=>\"User \\\"1\\\"\", :result=>\"Found a user.\", :model=>\"User \\\"1\\\"\"}}

      signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(B::E::Memo::Create, [{parameters: {id: "1"}}.freeze, {}])
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
      assert_equal '{:catch_args=>[[:catch_args, :database], [:db, :catch_args], [:catch_args, :database, :log]], :database=>["persist"], :log=>"Called ', ctx.inspect[0..131]
                                                              #   {:time} is not visible in {Log}

    # {:time} is injected
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(G::Create, [{catch_args: [], database: [], time: "yesterday"}, {}], **{})
      assert_equal '{:catch_args=>[[:catch_args, :database, :time], [:db, :catch_args, :time], [:catch_args, :database, :time, :log]], :database=>["persist"], :time=>"yesterday", :log=>"Called yesterday!"}', ctx.inspect#[0..65]
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
      assert_equal %{#<Trailblazer::Context::Container::WithAliases wrapped_options={\"contract.default\"=>Module} mutable_options={:inner_contract=>Module, :inner_contract_default=>Module} aliases={:\"contract.default\"=>:contract}>}, ctx.inspect
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
      assert_equal %{{:catch_args=>[[:catch_args, :database, :time], [:catch_args, :database, :time], [:catch_args, :database, :time, :log]], :database=>[], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}, ctx.inspect

    # default {:time}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(I::Create, [{catch_args: [], database: []}, {}])
      assert_equal '{:catch_args=>[[:catch_args, :database], [:catch_args, :database], [:catch_args, :database, :log]], :database=>[], :log=>"Called 20', ctx.inspect[0..130]
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
      assert_equal %{{:catch_args=>[[:catch_args, :database, :time], [:catch_args, :database, :time], [:catch_args, :database, :time, :log]], :database=>[], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}, ctx.inspect

    # default {:time}
    # injected/defaulted variables such as {:time} are NOT visible in the outer context if not configured otherwise.
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(X::Create, [{catch_args: [], database: []}, {}])        # {:time} is "gone", not here anymore!
      assert_equal '{:catch_args=>[[:catch_args, :database], [:catch_args, :database, :time], [:catch_args, :database, :log]], :database=>[], :log=>"Called 1!"}', ctx.inspect
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
      assert_equal %{{:database=>[], :catch_args=>[[:database, :catch_args, :time], [:database, :catch_args, :time, :log]], :time=>\"yesterday\", :log=>\"Called yesterday!\"}}, ctx.inspect

    # default {:time} from {:inject}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(J::Create, [{database: [], catch_args: []}, {}])
      assert_equal '{:database=>[], :catch_args=>[[:database, :catch_args], [:database, :catch_args, :log]], :log=>"Called tomorrow!"}', ctx.inspect


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
      assert_equal %{{:database=>[], :catch_args=>[[:database, :catch_args, :time, :ago], [:database, :catch_args, :time, :ago, :log]], :time=>\"yesterday\", :ago=>700, :log=>\"Called yesterday@700 years ago!\"}}, ctx.inspect

    # default {:time} from {:inject}
      _, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(K::Create, [{database: [], catch_args: [], ago: 700}, {}])
      assert_equal '{:database=>[], :catch_args=>[[:database, :catch_args, :ago], [:database, :catch_args, :ago, :log]], :ago=>700, :log=>"Called tomorrow@700 years ago!"}', ctx.inspect
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
      assert_equal %{{:database=>[], :catch_args=>[[:database, :catch_args, :volume], [:database, :catch_args, :volume, :log]], :volume=>99, :log=>"Called tomorrow@new@99!"}}, ctx.inspect
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
      ctx.inspect.must_equal %{{:time=>\"yesterday\", :log=>\"Called @ yesterday!\"}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Log, [{}, {}])
      ctx.inspect[0..18].must_equal '{:log=>"Called @ 20'

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
      ctx.inspect.must_equal %{{:model=>Object, :time=>\"yesterday\", :log=>\"Called @ yesterday!\"}}
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Z::Create, [{model: Object, }, {}])
      ctx.inspect[0..33].must_equal '{:model=>Object, :log=>"Called @ 2'

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
      ctx.inspect[0..68].must_equal '{:time=>"yesterday", :model=>Object, :log=>"Called @ yesterday and 20'
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Q::Create, [{model: Object}, {}])
      ctx.inspect[0..33].must_equal '{:model=>Object, :log=>"Called @ 2'

    end # it

# Composing input/output
# Composing Inject()
    it "Inject(): allows [] and ->{}" do
      module T
        class Create < Trailblazer::Activity::Railway
          step :write,
            Inject() => [:date, :time],
            Inject() => {current_user: ->(ctx, **kws) { ctx.keys.inspect + kws.inspect }} # FIXME: test/design kws here

          def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
            ctx[:log] = "Called @ #{time} and #{date.inspect} by #{current_user}!"
            ctx[:private] = ctx.keys.inspect
          end
        end
      end

    ## this must break because of missing {:date} - it is not defaulted, only injected when present.
      exception = assert_raises do
        signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{time: "yesterday", model: Object}, {}])
      end
      assert_match /missing keywords?: :?date/, exception.message

    ## {:time} is passed-through.
    ## {:date} is passed-through.
    ## {:current_user} is defaulted through Inject()
    ## Note that Inject()s are put "on top" of the default input, no whitelisting is happening, we can still see {:model}.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{time: "yesterday", date: "today", model: Object}, {}])
      assert_equal ctx.inspect, '{:time=>"yesterday", :date=>"today", :model=>Object, :log=>"Called @ yesterday and \"today\" by [:time, :date, :model]{:time=>\"yesterday\", :date=>\"today\", :model=>Object}!", :private=>"[:time, :date, :model, :current_user, :log]"}'

    ## {:time} is defaulted through kw
    ## {:current_user} is defaulted through Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{date: "today"}, {}])
      assert_equal ctx.inspect, '{:date=>"today", :log=>"Called @ Time.now and \"today\" by [:date]{:date=>\"today\"}!", :private=>"[:date, :current_user, :log]"}'

    ## {:current_user} is passed-through
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(T::Create, [{date: "today", current_user: Object}, {}])
      assert_equal ctx.inspect, '{:date=>"today", :current_user=>Object, :log=>"Called @ Time.now and \"today\" by Object!", :private=>"[:date, :current_user, :log]"}'
    end

    it "Inject() adds variables to In() when configured" do
      module TT
        class Create < Trailblazer::Activity::Railway
          step :write,
            Inject() => [:date, :time],
            Inject() => {current_user: ->(ctx, **) { ctx.keys.inspect }},
            In() => [:model],
            In() => {:something => :thing}

          def write(ctx, time: "Time.now", date:, current_user:, **) # {date} has no default configured.
            ctx[:log] = "Called @ #{time} and #{date.inspect} by #{current_user}!"
            ctx[:private] = ctx.keys.inspect
            ctx[:private] += ctx[:model].inspect
          end
        end
      end

    ## we can only see variables combined from Inject() and In() in the step.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TT::Create, [{date: "today", model: Object, something: 99}, {}])
      assert_equal ctx.inspect, '{:date=>"today", :model=>Object, :something=>99, :log=>"Called @ Time.now and \"today\" by [:date, :model, :something]!", :private=>"[:model, :thing, :date, :current_user, :log]Object"}'
    end

    it "In() DSL: single {In() => [:current_user]}" do
      module RR
        class Create < Trailblazer::Activity::Railway
          step :write,
            In() => [:current_user]

          def write(ctx, model: 9, current_user:, **)
            ctx[:incoming] = [model, current_user, ctx.keys]
          end
        end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RR::Create, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :incoming=>[9, nil, [:current_user]]}}
      # pass {:current_user} from the outside
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :incoming=>[9, Module, [:current_user]]}}
    end

    it "Output() DSL: single {Out() => [:current_user]}" do
      module RRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => [:model]

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside!
          end
        end
      end

    ## {:private} invisible in outer ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module}}

      # no {:model} for invocation
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRR::Create, [{time: "yesterday", current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :model=>[Module, [:time, :current_user, :private]]}}
    end

    it "Output() DSL: single {Out() => {:model => :user}}" do
      module RRRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => {:model => :song}

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song}!
          end
        end
      end

    ## {:model} is in outer ctx as we passed it into invocation, {:private} invisible:
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :song=>[Module, [:time, :model, :current_user, :private]]}}

      # no {:model} in outer ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRR::Create, [{time: "yesterday", current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :song=>[Module, [:time, :current_user, :private]]}}
    end

    it "Out() DSL: multiple overlapping {Out() => {:model => :user}} will create two aliases" do
      module RRRRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => {:model => :song, :current_user => :user},
          ## we refer to {:model} a second time here, it's still there in the Out pipe.
          ## and won't be in the final output hash.
            Out() => {:model => :hit}
          # }

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
          end
        end
      end

      # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :song=>[Module, [:time, :model, :current_user, :private]], :user=>Module, :hit=>[Module, [:time, :model, :current_user, :private]]}}

      # no {:model} in original ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :song=>[Module, [:time, :current_user, :private]], :user=>Module, :hit=>[Module, [:time, :current_user, :private]]}}
    end

  ## Delete a key in the outgoing ctx.
  ## Renaming can be applied on output hash with Out(read_from_aggregate: true)
  # NOTE: this is currently experimental.
    it "Out() DSL: {delete: true} forces deletion in outgoing ctx. Renaming can be applied on {:input_hash}" do
      module SSS
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => [:model],
            Out() => ->(ctx, **) {           {errors: {}} },
            Out(read_from_aggregate: true) => {:errors => :create_model_errors},
            Out(delete: true) => [:errors] # always {read_from_aggregate: true}

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
          end
        end
      end

    ## we basically rename {:errors} to {:create_model_errors} in the {:aggregate} itself.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(SSS::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module, :create_model_errors=>{}}}
    end

    it "Out() DSL: Dynamic lambda {Out() => ->{}}" do
      module RRRRRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => -> (inner_ctx, model:, private:, **) {
              {
                :model    => model,
                :private  => private.gsub(/./, "X") # CC number should be Xs outside.
              }
            }

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
          end
        end
      end

      # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module, :private=>"XXX"}}

      # no {:model} in original ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :model=>[Module, [:time, :current_user, :private]], :private=>"XXX"}}
    end

    it "Out() DSL: Dynamic lambda {Out() => ->{}}, order matters!" do
      module RRRRRRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => -> (inner_ctx, model:, private:, **) {
              {
                :model    => model,
                :private  => private.gsub(/./, "X") # CC number should be Xs outside.
              }
            },
            Out() => ->(inner_ctx, model:, **) { {:model => "<#{model}>"} }

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
          end
        end
      end

      # {:model} is in original ctx as we passed it into invocation, {:private} invisible:
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>"<[Module, [:time, :model, :current_user, :private]]>", :current_user=>Module, :private=>"XXX"}}

      # no {:model} in original ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRR::Create, [{time: "yesterday", current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :model=>"<[Module, [:time, :current_user, :private]]>", :private=>"XXX"}}
    end

    it "Out() DSL: { Out(with_outer_ctx: true) => ->{} }" do
      module RRRRRRRR
        class Create < Trailblazer::Activity::Railway
          step :create_model,
            Out() => -> (inner_ctx, model:, private:, **) {
              {
                :model    => model,
                :private  => private.gsub(/./, "X") # CC number should be Xs outside.
              }
            },
            Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx, model:, **) { {:song => model, private: outer_ctx[:private].to_i + 1} }

          def create_model(ctx, current_user:, **)
            ctx[:private] = "hi!"
            ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
          end
        end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRRR::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>[Module, [:time, :model, :current_user, :private]], :current_user=>Module, :private=>1, :song=>[Module, [:time, :model, :current_user, :private]]}}

      # no {:model} in original ctx
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRRR::Create, [{time: "yesterday", current_user: Module, private: 9}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :current_user=>Module, :private=>10, :model=>[Module, [:time, :current_user, :private]], :song=>[Module, [:time, :current_user, :private]]}}
    end

    it "{Out()} with {:output} warns and {:output} overrides everything" do
      output, err = capture_io {
        module S
          class Create < Trailblazer::Activity::Railway
            step :create_model,
              Out() => -> (inner_ctx, model:, private:, **) { raise },
              Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx, model:, **) { raise },
              output: {:model => :song}

            def create_model(ctx, current_user:, **)
              ctx[:private] = "hi!"
              ctx[:model]   = [current_user, ctx.keys]
            end
          end
        end
      }

      assert_match /\[Trailblazer\] You are mixing `:output/, err

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(S::Create, [{time: "yesterday", model: Object, current_user: Module}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :current_user=>Module, :song=>[Module, [:time, :model, :current_user, :private]]}}
    end

    it "{In()} with {:input} warns and {:input} overrides everything" do
      output, err = capture_io {
        module RRRRRRRRRR
          class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
            step :write,
              input:     [:model],
              In() => [:current_user],
              In() => ->(ctx, **) { raise }

            def write(ctx, model:, **)
              ctx[:incoming] = [model, ctx.keys]
            end
          end
        end
      }

      assert_match /\[Trailblazer\] You are mixing `:input/, err

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(RRRRRRRRRR::Create, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>"yesterday", :model=>Object, :incoming=>[Object, [:model]]}}
    end

    it "merging multiple input/output steps via In() DSL" do
      module R
        class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
          step :write,
            # all filters can see the original ctx:
            Inject() => {time: ->(ctx, **) { 99 }},
            In() => [:model],
            In() => [:current_user],
            # we can still see {:time} here:
            In() => ->(ctx, model:, time:nil, **) { {model: model.to_s + "hello! #{time}"} },
            Out() => ->(ctx, model:, **) { {out: [model, ctx[:incoming]]} }

          def write(ctx, model:, current_user:, **)
            ctx[:incoming] = [model, current_user, ctx.to_h]
          end
        end

      #@ Is the taskWrap inherited?
        class Update < Create
        end

        class Upsert < Update
          step :write, replace: :write,
            # inherit: [:variable_mapping],
          ## this overrides the existing taskWrap
            In() => [:model, :current_user]
        end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Create, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>\"yesterday\", :model=>Object, :out=>[\"Objecthello! yesterday\", [\"Objecthello! yesterday\", nil, {:model=>"Objecthello! yesterday", :current_user=>nil, :time=>"yesterday"}]]}}

    ## {:time} is defaulted by Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Create, [{model: Object}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :out=>["Objecthello! ", ["Objecthello! ", nil, {:model=>"Objecthello! ", :current_user=>nil, :time=>99}]]}}


    ## Inheriting I/O taskWrap filters
      ## {:time} is defaulted by Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Update, [{model: Object}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :out=>[\"Objecthello! \", [\"Objecthello! \", nil, {:model=>"Objecthello! ", :current_user=>nil, :time=>99}]]}}

    ## currently, the In() in Upsert overrides the inherited taskWrap.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(R::Upsert, [{model: Object}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :incoming=>[Object, nil, {:model=>Object, :current_user=>nil}]}}

    end

    #@ unit test
    it "i/o works for step, pass and fail and is automatically included in Path, Railway and FastTrack" do
      write_step_for = ->(strategy, method_name) do
        Class.new(strategy) do
          step :deviate
          send method_name, :write, In() => [:model],
            Out() => {:model => :write_model, :incoming => :incoming}

          def deviate(ctx, deviate: true, **)
            deviate
          end

          def write(ctx, model:, **)
            ctx[:incoming] = [model, ctx.keys]
          end
        end
      end

      #@ Path
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Path, :step), [{model: Object, ignore: 1}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

      #@ Railway
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :step), [{model: Object, ignore: 1}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :pass), [{model: Object, ignore: 1}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::Railway, :fail), [{model: Object, ignore: 1, deviate: false}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :deviate=>false, :write_model=>Object, :incoming=>[Object, [:model]]}}

      #@ FastTrack
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :step), [{model: Object, ignore: 1}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :pass), [{model: Object, ignore: 1}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :write_model=>Object, :incoming=>[Object, [:model]]}}

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(write_step_for.(Trailblazer::Activity::FastTrack, :fail), [{model: Object, ignore: 1, deviate: false}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :ignore=>1, :deviate=>false, :write_model=>Object, :incoming=>[Object, [:model]]}}
    end

    #@ unit test
    # it "In() and Inject() execution order" do
    #   module YYY
    #     class Create < Trailblazer::Activity::Railway
    #       step :write,
    #         # all filters can see the original ctx:
    #         # Inject() => {time: ->(ctx, **) { puts "& #{ctx.keys.inspect}"; 99 }},
    #         In() => ->(ctx, model:, **) {          {model_1: model + ctx.keys} },
    #         In() => ->(ctx, model:, ignore:, **) { {model_2: model + ctx.keys} }

    #       def write(ctx, model_1:, model_2:, **)
    #         ctx[:incoming]    = [model_1, model_2]
    #         ctx[:visible_ctx] = ctx.to_h
    #       end
    #     end
    #   end

    #   signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(YYY::Create, [{model: [], ignore: 1}, {}])
    #   assert_equal ctx.inspect, %{{:model=>[], :ignore=>1, :incoming=>[[asdfasdf], {:model=>Object, :current_user=>nil}]}}
    # end

    require "trailblazer/activity/dsl/linear/feature/variable_mapping/inherit"
    it "inherit: [:variable_mapping]" do
      module TTTTT
        class Create < Trailblazer::Activity::Railway # TODO: add {:inject}
          extend Trailblazer::Activity::DSL::Linear::VariableMapping::Inherit # this has to be done on the root level!

          step :write,
            # all filters can see the original ctx:
            Inject() => {time: ->(ctx, **) { 99 }},
            In() => ->(ctx,**) { {current_user: ctx[:current_user]} },
            Out() => {:current_user => :acting_user},
            Out() => [:incoming]

          def write(ctx, current_user:, time:, **)
            ctx[:incoming] = [ctx[:model], current_user, ctx.to_h]
          end
        end

        # raise Trailblazer::Activity::Introspect::Graph(Create).find(:write).data.keys.inspect

      #@ Is the taskWrap inherited?
        class Update < Create
        end

        # TODO: allow adding/modifying the inherited settings.
        class Upsert < Update
          step :write, replace: :write,
            inherit: [:variable_mapping],
              In()  => ->(ctx, model:, action:, **) { {model: model} }, # [:model]
              Out() => {:incoming => :output_of_write}, #
              Out(delete: true) => [:incoming] # as this is statically set in the superclass, we have to delete to make it invisible.
        end
      end

    # Create
      #= we don't see {:model} because Create doesn't have an In() for it.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Create, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>"yesterday", :model=>Object, :acting_user=>nil, :incoming=>[nil, nil, {:current_user=>nil, :time=>"yesterday"}]}}
      #@ {:time} is defaulted by Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Create, [{}, {}])
      assert_equal ctx.inspect, %{{:acting_user=>nil, :incoming=>[nil, nil, {:current_user=>nil, :time=>99}]}}

    # Update and Create work identically
      #= we don't see {:model} because Create doesn't have an In() for it.
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Update, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>"yesterday", :model=>Object, :acting_user=>nil, :incoming=>[nil, nil, {:current_user=>nil, :time=>"yesterday"}]}}

      #@ {:time} is defaulted by Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Update, [{}, {}])
      assert_equal ctx.inspect, %{{:acting_user=>nil, :incoming=>[nil, nil, {:current_user=>nil, :time=>99}]}}

    #= Upsert additionally sees {:model}
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Upsert, [{time: "yesterday", model: Object, action: :upsert}, {}])
      assert_equal ctx.inspect, %{{:time=>"yesterday", :model=>Object, :action=>:upsert, :acting_user=>nil, :output_of_write=>[Object, nil, {:current_user=>nil, :time=>"yesterday", :model=>Object}]}}

      #@ {:time} is defaulted by Inject()
      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(TTTTT::Upsert, [{model: Object, action: :upsert}, {}])
      assert_equal ctx.inspect, %{{:model=>Object, :action=>:upsert, :acting_user=>nil, :output_of_write=>[Object, nil, {:current_user=>nil, :time=>99, :model=>Object}]}}
    end

    #@ unit test
    it "accepts :initial_input_pipeline as normalizer option" do
      my_input_ctx = ->(wrap_ctx, original_args) do
      # The default ctx is the original ctx but with uppercased values.
        default_ctx = wrap_ctx[:original_ctx].collect { |k,v| [k.to_s.upcase, v.to_s.upcase] }.to_h

        Trailblazer::Activity::DSL::Linear::VariableMapping.merge_variables(default_ctx, wrap_ctx, original_args)
      end

      activity = Class.new(Trailblazer::Activity::Railway) do
        input_pipe = Trailblazer::Activity::TaskWrap::Pipeline.new([
          Trailblazer::Activity::TaskWrap::Pipeline.Row("input.init_hash", Trailblazer::Activity::DSL::Linear::VariableMapping.method(:initial_aggregate)),
        # we use the standard input pipeline but with our own default_ctx that has UPPERCASED variables and values.
          Trailblazer::Activity::TaskWrap::Pipeline.Row("input.my_input_ctx", my_input_ctx),
          Trailblazer::Activity::TaskWrap::Pipeline.Row("input.scope", Trailblazer::Activity::DSL::Linear::VariableMapping.method(:scope)),
        ]) # DISCUSS: use VariableMapping.initial_input_pipeline here, and modify it?

        step :write,
          initial_input_pipeline: input_pipe, In() => [:model]

        def write(ctx, model:, **)
          ctx[:incoming] = [model, ctx.to_h]
        end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{time: "yesterday", model: Object}, {}])
      assert_equal ctx.inspect, %{{:time=>"yesterday", :model=>Object, :incoming=>[Object, {:TIME=>"YESTERDAY", :MODEL=>"OBJECT", :model=>Object}]}}
    end

    #@ unit test
    it "accepts :initial_output_pipeline as normalizer option" do
      my_output_ctx = ->(wrap_ctx, original_args) do
        wrap_ctx[:aggregate] = wrap_ctx[:aggregate].collect { |k,v| [k.to_s.upcase, v.to_s.upcase] }.to_h

        return wrap_ctx, original_args
      end

      activity = Class.new(Trailblazer::Activity::Railway) do
        output_pipe = Trailblazer::Activity::DSL::Linear::VariableMapping::DSL.initial_output_pipeline()
        output_pipe = Trailblazer::Activity::TaskWrap::Extension([my_output_ctx, id: "my.output_uppercaser", append: "output.merge_with_original"]).(output_pipe)


        step :write,
          initial_output_pipeline: output_pipe, Out() => [:model]

        def write(ctx, model:, **)
          ctx[:current_user] = Module
        end
      end

      signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(activity, [{model: Object}, {}])
      assert_equal ctx.inspect, %{{"MODEL"=>"OBJECT"}}
    end



    # TODO: test if injections are discarded afterwards
    # TODO: can we use Context() from VariableMapping?
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
