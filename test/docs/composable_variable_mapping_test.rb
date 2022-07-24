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

#@ In() 1.1 {:model => :model}
  module A
    module Policy
      # Explicit policy, one way, not ideal as it results in a lot of code.
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

    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create, # callable class can be a step, too.
        In() => {:current_user => :user, :model => :model} # rename {:current_user} to {:user}
      #~meths
      include Steps
      #~meths end
    end

  end # A

  it "why do we need In() ?" do
    assert_invoke A::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

# In() 1.2
  module B
    Policy = A::Policy

    class Create < Trailblazer::Activity::Railway
      step :create_model
      step Policy::Create,
        In() => {:current_user => :user},
        In() => [:model]
      #~meths
      include Steps
      #~meths end
    end
  end

  it "In() can map and limit" do
    assert_invoke B::Create, current_user: Module, expected_ctx_variables: {model: Object}
  end

  it "Policy breach will add {ctx[:message]} and {:status}" do
    assert_invoke B::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, status: 422, message: "Command {create} not allowed!"}
  end

# Out() 1.1
  module D
    Policy = A::Policy

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
  end

  it "Out() can map" do
    #= policy didn't set any message
    assert_invoke C::Create, current_user: Module, expected_ctx_variables: {model: Object, message_from_policy: nil}
    #= policy breach, {message_from_policy} set.
    assert_invoke C::Create, current_user: nil, terminus: :failure, expected_ctx_variables: {model: Object, message_from_policy: "Command {create} not allowed!"}
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
