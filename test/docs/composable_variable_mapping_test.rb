require "test_helper"

class ComposableVariableMappingDocTest < Minitest::Spec
  class ApplicationPolicy
    def self.can?(model, user, mode)
      decision = !user.nil?
      Struct.new(:allowed?).new(decision)
    end
  end

  module Steps
    def create_model(ctx, **)
      ctx[:model] = Object
    end
  end

  module A
    #:policy
    module Policy
      # Explicit policy, not ideal as it results in a lot of code.
      class Create
        def self.call(ctx, model:, user:, **)
          decision = ApplicationPolicy.can?(model, user, :create) # FIXME: how does pundit/cancan do this exactly?
          #~decision

          if decision.allowed?
            return true
          else
            ctx[:status]  = 422 # we're not interested in this field.
            ctx[:message] = "Command {create} not allowed!"
            return false
          end
          #~decision end
        end
      end
    end
    #:policy end
  end

#@ 0.1 No In()
  module AA
    Policy = A::Policy

    #:no-in
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create # an imaginary policy step.
      #~meths
      include Steps
      #~meths end
    end
    #:no-in end
  end

  it "why do we need In() ? because we get an exception" do
    exception = assert_raises ArgumentError do
      #:no-in-invoke
      result = Trailblazer::Activity::TaskWrap.invoke(AA::Create, [{current_user: Module}])

      #=> ArgumentError: missing keyword: :user
      #:no-in-invoke end
    end

    assert_equal exception.message, "missing keyword: #{symbol_inspect_for(:user)}"
  end

  def symbol_inspect_for(name)
    if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7.0") || RUBY_ENGINE == 'jruby'
      "#{name}"
    else
      ":#{name}"
    end
  end

#@ In() 1.1 {:model => :model}
  module A
    #:in-mapping
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {
          :current_user => :user, # rename {:current_user} to {:user}
          :model        => :model # add {:model} to the inner ctx.
        }
      #~meths
      include Steps
      #~meths end
    end
    #:in-mapping end

  end # A

  it "why do we need In() ?" do
    assert_invoke A::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  module AAA
    #:in-mapping-keys
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step :show_ctx,
        In() => {
          :current_user => :user, # rename {:current_user} to {:user}
          :model        => :model # add {:model} to the inner ctx.
        }

      def show_ctx(ctx, **)
        p ctx.to_h
        #=> {:user=>#<User email:...>, :model=>#<Song name=nil>}
      end
      #~meths
      include Steps
      #~meths end
    end
    #:in-mapping-keys end

  end # A

  it "In() is only locally visible" do
    assert_invoke AAA::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

# In() 1.2
  module B
    Policy = A::Policy

    #:in-limit
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model]
      #~meths
      include Steps
      #~meths end
    end
    #:in-limit end
  end

  it "In() can map and limit" do
    assert_invoke B::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  it "Policy breach will add {ctx[:message]} and {:status}" do
    assert_invoke B::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, status: 422, message: "Command {create} not allowed!"}
  end

# In() 1.3 (callable)
  module BB
    Policy = A::Policy

    #:in-callable
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => ->(ctx, **) do
          # only rename {:current_user} if it's there.
          ctx[:current_user].nil? ? {} : {user: ctx[:current_user]}
        end,
        In() => [:model]
      #~meths
      include Steps
      #~meths end
    end
    #:in-callable end
  end

  it "In() can map and limit" do
    assert_invoke BB::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  it "exception because we don't pass {:current_user}" do
    exception = assert_raises ArgumentError do
      result = Trailblazer::Activity::TaskWrap.invoke(BB::Create, [{}, {}]) # no {:current_user}
    end

    assert_equal exception.message, "missing keyword: #{symbol_inspect_for(:user)}"
  end

# In() 1.4 (filter method)
  module BBB
    Policy = A::Policy

    #:in-method
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => :input_for_policy, # You can use an {:instance_method}!
        In() => [:model]

      def input_for_policy(ctx, **)
        # only rename {:current_user} if it's there.
        ctx[:current_user].nil? ? {} : {user: ctx[:current_user]}
      end
      #~meths
      include Steps
      #~meths end
    end
    #:in-method end
  end

  it{ assert_invoke BBB::Create, current_user: Module, expected_ctx_variables: {model: Object} }

# In() 1.5 (callable with kwargs)
  module BBBB
    Policy = A::Policy

    #:in-kwargs
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
                      # vvvvvvvvvvvv keyword arguments rock!
        In() => ->(ctx, current_user: nil, **) do
          current_user.nil? ? {} : {user: current_user}
        end,
        In() => [:model]
      #~meths
      include Steps
      #~meths end
    end
    #:in-kwargs end
  end

  it{ assert_invoke BBBB::Create, current_user: Module, expected_ctx_variables: {model: Object} }

# Out() 1.1
  module D
    Policy = A::Policy

    #:out-array
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message]
      #~meths
      include Steps
      #~meths end
    end
    #:out-array end
  end

  it "Out() can limit" do
    #= policy didn't set any message
    assert_invoke D::Create, current_user: Module, expected_ctx_variables: {model: Object, message: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke D::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message: "Command {create} not allowed!"}
  end

# Out() 1.2
  module C
    Policy = A::Policy

    #:out-hash
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => {:message => :message_from_policy}
      #~meths
      include Steps
      #~meths end
    end
    #:out-hash end
  end

  it "Out() can map" do
    #= policy didn't set any message
    assert_invoke C::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke C::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end


# Out() 1.3
  module DD
    Policy = A::Policy

    # Message = Struct.new(:data)
    #:out-callable
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => ->(ctx, **) do
          return {} unless ctx[:message]

          { # you always have to return a hash from a callable!
            :message_from_policy => ctx[:message]
          }
        end
      #~meths
      include Steps
      #~meths end
    end
    #:out-callable end
  end

  it "Out() can map with callable" do
    #= policy didn't set any message
    assert_invoke DD::Create, current_user: Module, expected_ctx_variables: {model: Object}
    #= policy breach, {message_from_policy} set.
    assert_invoke DD::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end

# Out() 1.4
  module DDD
    Policy = A::Policy

    #:out-kw
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => ->(ctx, message: nil, **) do
          return {} if message.nil?

          { # you always have to return a hash from a callable!
            :message_from_policy => message
          }
        end
      #~meths
      include Steps
      #~meths end
    end
    #:out-kw end
  end

  it "Out() can map with callable" do
    #= policy didn't set any message
    assert_invoke DDD::Create, current_user: Module, expected_ctx_variables: {model: Object}
    #= policy breach, {message_from_policy} set.
    assert_invoke DDD::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end

# Out() 1.6
  module DDDD
    Policy = A::Policy

    #:out-outer
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message],

        Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx, **) do
          {
            errors: outer_ctx[:errors].merge(policy_message: inner_ctx[:message])
          }
        end
      #~meths
      include Steps
      #~meths end
    end
    #:out-outer end
  end

  it "Out() with {outer_ctx}" do
    #= policy didn't set any message
    assert_invoke DDDD::Create, current_user: Module, errors: {}, expected_ctx_variables: {:errors=>{:policy_message=>nil}, model: Object, message: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke DDDD::Create, current_user: nil, errors: {}, terminus: :failure, expected_ctx_variables: {:errors=>{:policy_message=>"Command {create} not allowed!"}, :model=>Object, :message=>"Command {create} not allowed!"}
  end

# Macro 1.0
  module DDDDD
    Policy = A::Policy
    #:macro
    module Policy
      def self.Create()
        {
          task: Policy::Create,
          wrap_task: true,
          Trailblazer::Activity::Railway.In()  => {:current_user => :user},
          Trailblazer::Activity::Railway.In()  => [:model],
          Trailblazer::Activity::Railway.Out() => {:message => :message_from_policy},
        }
      end
    end
    #:macro end

    #:macro-use
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create()
      #~meths
      include Steps
      #~meths end
    end
    #:macro-use end
  end

  it "Out() with {outer_ctx}" do
    #= policy didn't set any message
    assert_invoke DDDDD::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke DDDDD::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message_from_policy=>"Command {create} not allowed!"}
  end

# Macro 1.1
  module DDDDDD
    Policy = DDDDD::Policy

    #:macro-merge
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create(),
        Out() => {:message => :copied_message} # user options!
      #~meths
      include Steps
      #~meths end
    end
    #:macro-merge end
  end

  it do
    #= policy didn't set any message
    assert_invoke DDDDDD::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil, :copied_message=>nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke DDDDDD::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message_from_policy=>"Command {create} not allowed!", :copied_message=>"Command {create} not allowed!"}
  end

  # Inheritance 1.0
  module EEE
    Policy = DDDDD::Policy

    #:inheritance-base
    class Create < Trailblazer::Activity::Railway
      extend Trailblazer::Activity::DSL::Linear::VariableMapping::Inherit # this has to be done on the root level!

      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message],
        id: :policy
      #~meths
      include Steps
      #~meths end
    end
    #:inheritance-base end

    # puts Trailblazer::Developer::Render::TaskWrap.(Create, id: :policy)
=begin
#:tw-render
puts Trailblazer::Developer::Render::TaskWrap.(Song::Operation::Create, id: :policy)
#:tw-render end
=end

=begin
#:tw-render-out
Song::Operation::Create
`-- policy
    |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
    |   |-- input.init_hash.............................. ............................................. VariableMapping.initial_aggregate
    |   |-- input.add_variables.0.994[...]............... {:current_user=>:user}....................... VariableMapping::AddVariables
    |   |-- input.add_variables.0.592[...]............... [:model]..................................... VariableMapping::AddVariables
    |   `-- input.scope.................................. ............................................. VariableMapping.scope
    |-- task_wrap.call_task..............Method
    `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
        |-- output.init_hash............................. ............................................. VariableMapping.initial_aggregate
        |-- output.add_variables.0.599[...].............. [:message]................................... VariableMapping::AddVariables::Output
        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original
#:tw-render-out end
=end

    #:inheritance-sub
    class Admin < Create
      step Policy::Create,
        Out() => {:message => :raw_message_for_admin},
        inherit: [:variable_mapping],
        id: :policy,      # you need to reference the :id when your step
        replace: :policy
    end
    #:inheritance-sub end

    # puts Trailblazer::Developer::Render::TaskWrap.(Admin, id: :policy)
=begin
#:sub-pipe
puts Trailblazer::Developer::Render::TaskWrap.(Admin, id: :policy)

ComposableVariableMappingDocTest::EEE::Admin
# `-- policy
#     |-- task_wrap.input..................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Input
#     |   |-- input.init_hash.............................. ............................................. VariableMapping.initial_aggregate
#     |   |-- input.add_variables.0.994[...]............... {:current_user=>:user}....................... VariableMapping::AddVariables
#     |   |-- input.add_variables.0.592[...]............... [:model]..................................... VariableMapping::AddVariables
#     |   `-- input.scope.................................. ............................................. VariableMapping.scope
#     |-- task_wrap.call_task..............Method
#     `-- task_wrap.output.................Trailblazer::Activity::DSL::Linear::VariableMapping::Pipe::Output
#         |-- output.init_hash............................. ............................................. VariableMapping.initial_aggregate
#         |-- output.add_variables.0.599[...].............. [:message]................................... VariableMapping::AddVariables::Output
#         |-- output.add_variables.0.710[...].............. {:message=>:raw_message_for_admin}........... VariableMapping::AddVariables::Output
#        `-- output.merge_with_original................... ............................................. VariableMapping.merge_with_original
#:sub-pipe end
=end
  end

  it do
    #= policy didn't set any message
    assert_invoke EEE::Admin, current_user: Module, expected_ctx_variables: {model: Object, message: nil, :raw_message_for_admin=>nil}
    assert_invoke EEE::Admin, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message=>"Command {create} not allowed!", :raw_message_for_admin=>"Command {create} not allowed!"}
  end

  # Inject() 1.0
  module GGG
    class ApplicationPolicy
      def self.can?(model, user, action)
        decision = !user.nil? && action == :create
        Struct.new(:allowed?).new(decision)
      end
    end

    #:policy-check
    module Policy
      class Check
                                        # vvvvvvvvvvvvvvv-- defaulted keyword arguments
        def self.call(ctx, model:, user:, action: :create, **)
          decision = ApplicationPolicy.can?(model, user, action) # FIXME: how does pundit/cancan do this exactly?
          #~decision

          if decision.allowed?
            return true
          else
            ctx[:message] = "Command {#{action}} not allowed!"
            return false
          end
          #~decision end
        end
      end
    end
    #:policy-check end

    #:inject
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model],
        Inject() => [:action]
      #~meths
      include Steps
      #~meths end
    end
    #:inject end
  end

  it "Inject()" do
    #= {:action} defaulted to {:create}
    assert_invoke GGG::Create, current_user: Module, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:create}
    assert_invoke GGG::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}, policy breach
    assert_invoke GGG::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end

  module GGGG
    Policy = GGG::Policy

    #:no-inject
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model, :action]
      #~meths
      include Steps
      #~meths end
    end
    #:no-inject end
  end

  it "not using Inject()" do
    #= {:action} not defaulted as In() passes nil
    assert_invoke GGGG::Create, current_user: Module, expected_ctx_variables: {model: Object, message: "Command {} not allowed!"}, terminus: :failure

    #= {:action} set explicitely to {:create}
    assert_invoke GGGG::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}
    assert_invoke GGGG::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end

  module GGGGG
    ApplicationPolicy = GGG::ApplicationPolicy

    #:policy-check-nodef
    module Policy
      class Check
                                        # vvvvvvv-- no defaulting!
        def self.call(ctx, model:, user:, action:, **)
          decision = ApplicationPolicy.can?(model, user, action) # FIXME: how does pundit/cancan do this exactly?
          #~decision

          if decision.allowed?
            return true
          else
            ctx[:message] = "Command {#{action}} not allowed!"
            return false
          end
          #~decision end
        end
      end
    end
    #:policy-check-nodef end

    #:inject-default
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model],
        Inject() => {
          action: ->(ctx, **) { :create }
        }
      #~meths
      include Steps
      #~meths end
    end
    #:inject-default end
  end

  it "Inject() with default" do
    #= {:action} defaulted by Inject()
    assert_invoke GGGGG::Create, current_user: Module, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:create}
    assert_invoke GGGGG::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}
    assert_invoke GGGGG::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end

  # def operation_for(&block)
  #   namespace = Module.new
  #   # namespace::Policy = A::Policy
  #   namespace.const_set :Policy, A::Policy

  #   namespace.module_eval do
  #     operation = yield
  #     operation.class_eval do
  #       include Steps
  #     end
  #   end
  # end # operation_for
end

#@ Out() 1.5
#@   First, blacklist all, then add whitelisted.
class OutMultipleTimes < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy

  class Create < Trailblazer::Activity::Railway
    step :model
    step Policy::Create,
      In() => {:current_user => :user},
      In() => [:model],
      Out() => [],
      Out() => [:message]

    #~meths
    def model(ctx, **)
      ctx[:model] = Object
    end
    #~meths end
  end

  it "Out() can be used sequentially" do
    #= policy didn't set any message
    assert_invoke Create, current_user: Module, expected_ctx_variables: {model: Object, message: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message: "Command {create} not allowed!"}
  end
end
