require "test_helper"

module Y
  class DocsMechanicsTest < Minitest::Spec
    Memo = Module.new
    it "what" do
      #:instance-method
      module Memo::Activity
        class Create < Trailblazer::Activity::Railway
          step :validate

          #~meths
          def validate(ctx, params:, **)
            params.key?(:memo) ? true : false # return value matters!
          end
          #~meths end
        end
      end
      #:instance-method end

      #:instance-method-call
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil}) #!hint result = Memo::Operation::Create.call(params: {memo: nil})
      #:instance-method-call end
      assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true

      #:instance-method-implicit-call
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil}) #!hint result = Memo::Operation::Create.(params: {memo: nil})
      # #:instance-method-implicit-call end
      assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true
    end
  end
end

class ReadfromCtx_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:ctx-read
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        #~meths
        step :save

        def save(*); true; end
        #~meths end
        def validate(ctx, **)
          p ctx[:params] #=> {:memo=>nil}
        end
      end
    end
    #:ctx-read end

    #:ctx-read-call
    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil})
    #:ctx-read-call end
    assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true
  end
end

class ReadfromCtxKwargs_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        #~meths
        step :save

        def save(*); true; end
        #~meths end
        #:ctx-read-kwargs
        def validate(ctx, params:, **)
          p params #=> {:memo=>nil}
        end
        #:ctx-read-kwargs end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil})
    assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true

    user = Object
    assert_raises ArgumentError do
      #:kwargs-error
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, current_user: user)
      #=> ArgumentError: missing keyword: :params
      #       memo/operation/create.rb:9:in `validate'
      #:kwargs-error end
    end
  end
end

class WriteToCtx_DocsMechanicsTest < Minitest::Spec
  class Memo
    def initialize(*); end
  end
  it "what" do
    #:ctx-write-read
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        step :save # sets ctx[:model]
        step :notify
        #~body
        #~meths
        def validate(ctx, params:, **)
          true
        end

        def send_email(*)
          true
        end
        #~meths end
        #:ctx-write
        def save(ctx, params:, **)
          ctx[:model] = Memo.new(params[:memo])
        end
        #~body end
        #:ctx-write end
        def notify(ctx, model:, **)
          send_email(model)
        end
      end
    end
    #:ctx-write-read end

    #:result-read
    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: {content: "remember that"}})

    ctx[:model] #=> #<Memo id: 1, ...> #!hint result[:model] #=> #<Memo id: 1, ...>
    #:result-read end

    #:result-success
    puts signal.to_h[:semantic] #=> true #!hint puts result.success? #=> true
    #:result-success end

    assert_equal ctx[:model].class, Memo #!hint assert_equal result[:model].class, Memo
    assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true

    user = Object
    assert_raises ArgumentError do
      #:kwargs-error
      signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, current_user: user)
      #=> ArgumentError: missing keyword: :params
      #       memo/operation/create.rb:9:in `validate'
      #:kwargs-error end
    end
  end
end

class ReturnValueSuccess_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        #~meths
        step :save

        def save(*); true; end
        #~meths end
        #:return-success
        def validate(ctx, params:, **)
          params.key?(:memo) # => true/false
        end
        #:return-success end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil})
    assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true
  end
end

class ReturnValueFailure_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        #~meths
        step :save

        def save(*); true; end
        #~meths end
        #:return-failure
        def validate(ctx, params:, **)
          nil
        end
        #:return-failure end
      end
    end

    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil})
    assert_equal signal.to_h[:semantic], :failure #!hint assert_equal result.success?, false
  end
end

class ReturnSignal_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:signal-operation
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        class NetworkError < Trailblazer::Activity::Signal #!hint class NetworkError < Trailblazer::Activity::Signal
        end
        #~meths
        #:signal-steps
        step :validate
        step :save
        left :handle_errors
        step :notify,
          Output(NetworkError, :network_error) => End(:network_error)
        #:signal-steps end
        def save(ctx, **)
          ctx[:model] = Object
        end
        def validate(ctx, params:, **)
          true
        end
        def send_email(model)
          true
        end
        def check_network(params)
          ! params[:network_broken]
        end

        #:return-signal
        def notify(ctx, model:, params:, **)
          return NetworkError unless check_network(params)

          send_email(model)
        end
        #:return-signal end
        #~meths end
      end
    end
    #:signal-operation end

    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil, network_broken: false})
    assert_equal signal.to_h[:semantic], :success #!hint assert_equal result.success?, true

    signal, (ctx, _) = Trailblazer::Activity.(Memo::Activity::Create, params: {memo: nil, network_broken: true})
    assert_equal signal.to_h[:semantic], :network_error #!hint assert_equal result.success?, false
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:network_error>) #!hint assert_equal result.event.inspect, %(#<Trailblazer::Activity::End semantic=:network_error>)
  end
end

class Classmethod_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:class-method
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        #~meths
        # Define {Memo::Activity::Create.validate}
        def self.validate(ctx, params:, **)
          params.key?(:memo) ? true : false # return value matters!
        end
        #~meths end

        step method(:validate)
      end
    end
    #:class-method end
  end
end

class Module_Classmethod_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:module-step
    # Reusable steps in a module.
    module Steps
      def self.validate(ctx, params:, **)
        params.key?(:memo) ? true : false # return value matters!
      end
    end
    #:module-step end

    #:module-method
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step Steps.method(:validate)
      end
    end
    #:module-method end
  end
end

class Callable_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:callable-step
    module Validate
      def self.call(ctx, params:, **)
        valid?(params) ? true : false # return value matters!
      end

      def valid?(params)
        params.key?(:memo)
      end
    end
    #:callable-step end

    #:callable-method
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step Validate
      end
    end
    #:callable-method end
  end
end

class Lambda_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:lambda-step
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step ->(ctx, params:, **) { p params.inspect }
      end
    end
    #:lambda-step end
  end
end

class Inheritance_DocsMechanicsTest < Minitest::Spec
  Memo = Module.new
  it "what" do
    #:inherit-create
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :create_model
        step :validate
        step :save
        #~meths
        include T.def_steps(:create_model, :validate, :save)
        #~meths end
      end
    end
    #:inherit-create end

    #:inherit-update-empty
    module Memo::Activity
      class Update < Create
      end
    end
    #:inherit-update-empty end

    #:inherit-update
    module Memo::Activity
      class Update < Create
        step :find_model, replace: :create_model
        #~meths
        include T.def_steps(:find_model)
        #~meths end
      end
    end
    #:inherit-update end

    assert_invoke Memo::Activity::Create, seq: "[:create_model, :validate, :save]"
    assert_invoke Memo::Activity::Update, seq: "[:find_model, :validate, :save]"
  end
end

