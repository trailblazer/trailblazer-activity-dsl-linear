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
end

#@ 0.1 No In()
class CVNoInTest < Minitest::Spec
  Memo   = Module.new
  Policy = ComposableVariableMappingDocTest::A::Policy

  #:no-in
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create # an imaginary policy step.
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:no-in end

  it "why do we need In() ? because we get an exception" do
    exception = assert_raises ArgumentError do
      #:no-in-invoke
      result = Trailblazer::Activity.(Memo::Activity::Create, current_user: Module)

      #=> ArgumentError: missing keyword: :user
      #:no-in-invoke end
    end

    assert_equal exception.message, "missing keyword: #{Trailblazer::Core.symbol_inspect_for(:user)}"
  end
end

#@ In() 1.1 {:model => :model}
class CVInMappingHashTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

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
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
    #:in-mapping end

  end # A

  it "why do we need In() ?" do
    assert_invoke A::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  #:in-mapping-keys
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step :show_ctx,
        In() => {
          :current_user => :user, # rename {:current_user} to {:user}
          :model        => :model # add {:model} to the inner ctx.
        }

      def show_ctx(ctx, **)
        p ctx.to_h
        #=> {:user=>#<User email:...>, :model=>#<Memo name=nil>}
      end
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:in-mapping-keys end

  it "In() is only locally visible" do
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end
end

# In() 1.2
class CVInLimitTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:in-limit
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:in-limit end

  it "In() can map and limit" do
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  it "Policy breach will add {ctx[:message]} and {:status}" do
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, status: 422, message: "Command {create} not allowed!"}
  end
end

# In() 1.3 (callable)
class CVInCallableTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:in-callable
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => ->(ctx, **) do
          # only rename {:current_user} if it's there.
          ctx[:current_user].nil? ? {} : {user: ctx[:current_user]}
        end,
        In() => [:model]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:in-callable end

  it "In() can map and limit" do
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  it "exception because we don't pass {:current_user}" do
    exception = assert_raises ArgumentError do
      result = Trailblazer::Activity.(Memo::Activity::Create, {}) # no {:current_user}
    end

    assert_equal exception.message, "missing keyword: #{Trailblazer::Core.symbol_inspect_for(:user)}"
  end
end

# In() 1.4 (filter method)
class CVInMethodTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:in-method
  module Memo::Activity
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
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:in-method end

  it { assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object} }
end

# In() 1.5 (callable with kwargs)
class CVInKwargsTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:in-kwargs
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
                      # vvvvvvvvvvvv keyword arguments rock!
        In() => ->(ctx, current_user: nil, **) do
          current_user.nil? ? {} : {user: current_user}
        end,
        In() => [:model]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:in-kwargs end

  it { assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object} }
end

# Out() 1.1
class CVOutTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo = Module.new

  #:out-array
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:out-array end

  it "Out() can limit" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object, message: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message: "Command {create} not allowed!"}
  end

end

# Out() 1.2
class CVOutHashTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo = Module.new

  #:out-hash
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => {:message => :message_from_policy}
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:out-hash end

  it "Out() can map" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end
end

# Out() 1.3
class CVOutCallableTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo = Module.new

  # Message = Struct.new(:data)
  #:out-callable
  module Memo::Activity
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
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:out-callable end

  it "Out() can map with callable" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end
end

# Out() 1.4
class CVOutKwTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:out-kw
  module Memo::Activity
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
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:out-kw end

  it "Out() can map with callable" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
  end
end

# Out() 1.6
class CVOutOuterTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:out-outer
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message],

        Out(with_outer_ctx: true) => ->(inner_ctx, outer_ctx:, **) do
          {
            errors: outer_ctx[:errors].merge(policy_message: inner_ctx[:message])
          }
        end
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:out-outer end

  it "Out() with {outer_ctx}" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, errors: {}, expected_ctx_variables: {:errors=>{:policy_message=>nil}, model: Object, message: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, errors: {}, terminus: :failure, expected_ctx_variables: {:errors=>{:policy_message=>"Command {create} not allowed!"}, :model=>Object, :message=>"Command {create} not allowed!"}
  end
end

# Macro 1.0
class CVMacroTest < Minitest::Spec
  Policy = ComposableVariableMappingDocTest::A::Policy
  Memo   = Module.new

  #:macro
  module Policy
    def self.Create()
      {
        task: Policy::Create,
        wrap_task: true,
        Trailblazer::Activity::Railway.In()  => {:current_user => :user}, #!hint Trailblazer::Activity::Railway.In()  => {:current_user => :user},
        Trailblazer::Activity::Railway.In()  => [:model], #!hint Trailblazer::Activity::Railway.In()  => [:model],
        Trailblazer::Activity::Railway.Out() => {:message => :message_from_policy}, #!hint Trailblazer::Activity::Railway.Out() => {:message => :message_from_policy},
      }
    end
  end
  #:macro end

  #:macro-use
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create()
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:macro-use end

  it "Out() with {outer_ctx}" do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message_from_policy=>"Command {create} not allowed!"}
  end
end

# Macro 1.1
class CVMacroMergeTest < Minitest::Spec
  Policy = CVMacroTest::Policy
  Memo   = Module.new

  #:macro-merge
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create(),
        Out() => {:message => :copied_message} # user options!
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:macro-merge end

  it do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil, :copied_message=>nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke Memo::Activity::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message_from_policy=>"Command {create} not allowed!", :copied_message=>"Command {create} not allowed!"}
  end
end

# Inheritance 1.0
class CVInheritanceTest < Minitest::Spec
  Policy = CVMacroTest::Policy
  Memo   = Module.new

  #:inheritance-base
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway

      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model],
        Out() => [:message],
        id: :policy
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:inheritance-base end

    # puts Trailblazer::Developer::Render::TaskWrap.(Create, id: :policy)
=begin
#:tw-render
puts Trailblazer::Developer::Render::TaskWrap.(Memo::Activity::Create, id: :policy)
#:tw-render end
=end

=begin
#:tw-render-out
Memo::Activity::Create
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
  module Memo::Activity
    class Admin < Create
      step Policy::Create,
        Out() => {:message => :raw_message_for_admin},
        inherit: [:variable_mapping],
        id: :policy,      # you need to reference the :id when your step
        replace: :policy
    end
  end
  #:inheritance-sub end

    # puts Trailblazer::Developer::Render::TaskWrap.(Admin, id: :policy)
=begin
#:sub-pipe
puts Trailblazer::Developer::Render::TaskWrap.(Memo::Activity::Admin, id: :policy)

Memo::Activity::Admin
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

  it do
    #= policy didn't set any message
    assert_invoke Memo::Activity::Admin, current_user: Module, expected_ctx_variables: {model: Object, message: nil, :raw_message_for_admin=>nil}
    assert_invoke Memo::Activity::Admin, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, :message=>"Command {create} not allowed!", :raw_message_for_admin=>"Command {create} not allowed!"}
  end
end

# Inject() 1.0
class CVInjectTest < Minitest::Spec
  Memo   = Module.new

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
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model],
        Inject() => [:action]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:inject end

  it "Inject()" do
    #= {:action} defaulted to {:create}
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:create}
    assert_invoke Memo::Activity::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}, policy breach
    assert_invoke Memo::Activity::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end
end

class CVNoInjectTest < Minitest::Spec
  Policy = CVInjectTest::Policy
  Memo   = Module.new

  #:no-inject
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model, :action]
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:no-inject end

  it "not using Inject()" do
    #= {:action} not defaulted as In() passes nil
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object, message: "Command {} not allowed!"}, terminus: :failure

    #= {:action} set explicitely to {:create}
    assert_invoke Memo::Activity::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}
    assert_invoke Memo::Activity::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end
end

class CVInjectDefaultTest < Minitest::Spec
  ApplicationPolicy = CVInjectTest::ApplicationPolicy
  Memo   = Module.new

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
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model],
        Inject(:action) => ->(ctx, **) { :create }
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:inject-default end

  it "Inject() with default" do
    #= {:action} defaulted by Inject()
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:create}
    assert_invoke Memo::Activity::Create, current_user: Module, action: :create, expected_ctx_variables: {model: Object}

    #= {:action} set explicitely to {:update}
    assert_invoke Memo::Activity::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object, message: "Command {update} not allowed!"}, terminus: :failure
  end
end

class CVInjectOverrideTest < Minitest::Spec
  Policy = CVInjectDefaultTest::Policy
  Memo   = Module.new

  #:inject-override
  module Memo::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Check,
        In() => {:current_user => :user},
        In() => [:model],
        #:inject_override_iso
        Inject(:action, override: true) => ->(*) { :create } # always used.
        #:inject_override_iso end
      #~meths
      include ComposableVariableMappingDocTest::Steps
      #~meths end
    end
  end
  #:inject-override end

  it "Inject() with default" do
    #= {:action} override
    assert_invoke Memo::Activity::Create, current_user: Module, expected_ctx_variables: {model: Object}

    #= {:action} still overridden
    assert_invoke Memo::Activity::Create, current_user: Module, action: :update, expected_ctx_variables: {model: Object}

    current_user = Module

    #:inject-override-call
    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create,
      current_user: current_user,
      action: :update # this is always overridden.
    )
    #~ctx_to_result
    puts ctx[:model] #=> #<Memo id: 1, ...>
    #~ctx_to_result end
    #:inject-override-call end

    assert_equal ctx[:model], Object
  end
end

  # def operation_for(&block)
  #   namespace = Module.new
  #   # namespace::Policy = ComposableVariableMappingDocTest::A::Policy
  #   namespace.const_set :Policy, A::Policy

  #   namespace.module_eval do
  #     operation = yield
  #     operation.class_eval do
  #       include ComposableVariableMappingDocTest::Steps
  #     end
  #   end
  # end # operation_for

class DefaultInjectOnlyTest < Minitest::Spec
  it "Inject(), only, without In()" do
    class Create < Trailblazer::Activity::Railway
      step :write,
        Inject() => { name: ->(ctx, field:, **) { field } }

      def write(ctx, name: nil, **)
        ctx[:write] = %{
name:     #{name.inspect}
}
      end
    end

    assert_invoke Create, field: Module, expected_ctx_variables: {write: %{
name:     Module
}}
  end
end

class PassthroughInjectOnlyTest < Minitest::Spec
  it "Inject() => [...], only, without In()" do
    class Create < Trailblazer::Activity::Railway
      step :write,
        Inject() => [:name]

      def write(ctx, name: nil, **)
        ctx[:write] = %{
name:     #{name.inspect}
}
      end
    end

    assert_invoke Create, name: Module, expected_ctx_variables: {write: %{
name:     Module
}}
  end
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


class IoOutDeleteTest < Minitest::Spec
  #@ Delete a key in the outgoing ctx.
  it "Out() DSL: {delete: true} forces deletion in aggregate." do
    class Create < Trailblazer::Activity::Railway
      step :create_model,
        Out()             => [:model],
        Out()             => ->(ctx, **) {
          {errors: {},  # this is deleted.
          status: 200}  # this sticks around.
        },
        Out(delete: true) => [:errors] # always deletes from aggregate.

      def create_model(ctx, current_user:, **)
        ctx[:private] = "hi!"
        ctx[:model]   = [current_user, ctx.keys]
      end
    end

    assert_invoke Create, current_user: Object, expected_ctx_variables: {
      model: [Object, [:seq, :current_user, :private]],
      :status=>200,
    }
  end
end

# {:read_from_aggregate} for the moment is only supposed to be used with SetVariable filters.
class IoOutDeleteReadFromAggregateTest < Minitest::Spec
  #@ Rename a key *in the aggregate* and delete the original in {aggregate}.
  # NOTE: this is currently experimental.
  it "Out() DSL: {delete: true} forces deletion in outgoing ctx. Renaming can be applied on {:input_hash}" do
    class Create < Trailblazer::Activity::Railway
      step :create_model,
        Out() => [:model],
        Out() => ->(ctx, **) { {errors: {}} },
        Out(read_from_aggregate: true) => {:errors => :create_model_errors},
        Out(delete: true) => [:errors] # always on aggregate.

      def create_model(ctx, current_user:, **)
        ctx[:private] = "hi!"
        ctx[:model]   = [current_user, ctx.keys] # we want only this on the outside, as {:song} and {:hit}!
      end
    end

  #@ we basically rename {:errors} to {:create_model_errors} in the {:aggregate} itself.
    assert_invoke Create, current_user: Object, expected_ctx_variables: {
      model: [Object, [:seq, :current_user, :private]],
      create_model_errors: {},
    }
  end
end

#@ In() can override Inject() if it was added last.
class InInjectSortingTest < Minitest::Spec
  it do
    activity = Class.new(Trailblazer::Activity::Railway) do #!hint activity = Class.new(Trailblazer::Activity::Railway) do
      step :params,
        Inject()  => [:params],
        In()      => ->(ctx, **) { {params: {id: 1}}  }

      def params(ctx, params:, **)
        ctx[:captured_params] = params.inspect
      end
    end

    assert_invoke activity, expected_ctx_variables: {captured_params: "#{{:id=>1}}"}
    assert_invoke activity, params: {id: nil}, expected_ctx_variables: {params: {id: nil}, captured_params: "#{{:id=>1}}"}
  end
end
