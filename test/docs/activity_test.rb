require "test_helper"

class DocsActivityTest < Minitest::Spec
  Memo = Struct.new(:body) do
    def self.find_by(*)
      Memo.new
    end

    def update_attributes(*)

    end
  end

  describe "step types" do
    it "allows " do
      user = Object.new.instance_exec { def can?(*); true; end; self }
      module A
        #:task-style-class
        class AuthorizeForCreate
          def self.call(ctx, current_user:, **)
            current_user.can?(Memo, :create)
          end
        end
        #:task-style-class end

        #:task-style-module
        module Authorizer
          module_function

          def memo_create(ctx, current_user:, **)
            current_user.can?(Memo, :create)
          end
        end
        #:task-style-module end

        module Memo; end

        #:task-style-1
        class Memo::Create < Trailblazer::Activity::Railway
          def self.authorize(ctx, current_user:, **)
            current_user.can?(Memo, :create)
          end

          step method(:authorize)
        end
        #:task-style-1 end

        module B
          module Memo; end
          #:task-style-2
          class Memo::Create < Trailblazer::Activity::Railway
            class << self
              def authorize(ctx, current_user:, **)
                current_user.can?(Memo, :create)
              end
              # more methods...
            end

            step method(:authorize)
          end
          #:task-style-2 end
        end

        module BB
          module Memo; end
          #:task-style-instance-method
          class Memo::Create < Trailblazer::Activity::Railway
            step :authorize
            # ...

            def authorize(ctx, current_user:, **)
              current_user.can?(Memo, :create)
            end
          end
          #:task-style-instance-method end
        end

        module C
          module Memo; end
          #:task-style-3
          class Memo::Create < Trailblazer::Activity::Railway
            #~mod
            step Authorizer.method(:memo_create)
            #~mod end
            #~callable
            step AuthorizeForCreate
            #~callable end
          end
          #:task-style-3 end
        end # C

        class Proxy < Struct.new(:query_class, :reader)
          # Called in {#assert_call_for}
          def inspect
            query_class.send(reader)
          end
        end

        module D
          class Memo < Struct.new(:data)
            class << self
              def new(args)
                @last_object = super(args)
              end

              attr_reader :last_object
            end

            def save
              true
            end
          end

          #:task-implementation
          module Memo::Operation
            class Create < Trailblazer::Activity::Railway
              def self.create_model(ctx, **)
                attributes = ctx[:attrs]           # read from ctx

                ctx[:model] = Memo.new(attributes) # write to ctx

                #~method
                ctx[:model].save ? true : false    # return value matters
                #~method end
              end

              step method(:create_model)
              # ...
            end
          end
          #:task-implementation end

          module D1
            class Memo < Memo; end

            class Memo::Create < Trailblazer::Activity::Railway
              #:task-implementation-kws
              def self.create_model(ctx, attrs:, **) # kw args!
                #~method
                ctx[:model] = Memo.new(attrs)        # write to ctx

                #~method end
                ctx[:model].save ? true : false      # return value matters
              end
              #:task-implementation-kws end

              step method(:create_model)
              # ...
            end
          end

          module D2
            class Memo < D::Memo
              def save
                raise if data.is_a?(Hash) && data[:not_valid]
                true
              end
            end

            #:task-implementation-signal
            module Memo::Operation
              class Create < Trailblazer::Activity::Railway
                DatabaseError = Class.new(Trailblazer::Activity::Signal) # subclass Signal

                def create_model(ctx, attrs:, **)
                  ctx[:model] = Memo.new(attrs)

                  begin
                    return ctx[:model].save ? true : false  # binary return values
                  rescue
                    return DatabaseError                    # third return value
                  end
                end
                #~method
                def handle_db_error(*)
                  true
                end
                #~method end

                step :create_model,
                  Output(DatabaseError, :handle_error) => Id(:handle_db_error)
                step :handle_db_error,
                  magnetic_to: nil, Output(:success) => Track(:failure)
              end
            end
            #:task-implementation-signal end
          end # D2
        end # D
      end # A

      assert_invoke A::Memo::Create, current_user: user

      assert_invoke A::B::Memo::Create, current_user: user

      assert_invoke A::BB::Memo::Create, current_user: user

      assert_invoke A::C::Memo::Create, current_user: user

      assert_invoke A::D::Memo::Operation::Create, current_user: user, expected_ctx_variables: {model: A::Proxy.new(A::D::Memo, :last_object)}

      assert_invoke A::D::D1::Memo::Operation::Create, attrs: {body: "Wine"}, expected_ctx_variables: {model: A::Proxy.new(A::D::Memo, :last_object)}

      assert_invoke A::D::D2::Memo::Operation::Create, attrs: {body: "Wine"}, expected_ctx_variables: {model: A::Proxy.new(A::D::D2::Memo, :last_object)}
      #@ invalid data
      assert_invoke A::D::D2::Memo::Operation::Create, attrs: {not_valid: true}, expected_ctx_variables: {model: A::Proxy.new(A::D::D2::Memo, :last_object)}, terminus: :failure
    end
  end

  describe "#what" do
    it do
      #:overview
      class Memo::Update < Trailblazer::Activity::Railway
        #
        # here goes your business logic
        #
        def self.find_model(ctx, id:, **)
          ctx[:model] = Memo.find_by(id: id)
        end

        def self.validate(ctx, params:, **)
          return true if params[:body].is_a?(String) && params[:body].size > 10
          ctx[:errors] = "body not long enough"
          false
        end

        def self.save(_ctx, model:, params:, **)
          model.update_attributes(params)
        end

        def self.log_error(ctx, params:, **)
          ctx[:log] = "Some idiot wrote #{params.inspect}"
        end
        #
        # here comes the DSL describing the layout of the activity
        #
        step method(:find_model)
        step method(:validate), Output(:failure) => End(:validation_error)
        step method(:save)
        fail method(:log_error)
      end
      #:overview end

      #:overview-call
      ctx = {id: 1, params: {body: "Awesome!"}}

      event, (ctx, *) = Memo::Update.([ctx, {}])
      #:overview-call end

      _(ctx.inspect).must_equal '{:id=>1, :params=>{:body=>"Awesome!"}, :model=>#<struct DocsActivityTest::Memo body=nil>, :errors=>"body not long enough"}'

    end
  end

  # circuit interface
  it do
    #:circuit-interface-create
    class Create < Trailblazer::Activity::Railway
      #:circuit-interface-validate
      def self.validate((ctx, flow_options), **_circuit_options)
        #~method
        is_valid = ctx[:name].nil? ? false : true

        ctx    = ctx.merge(validate_outcome: is_valid) # you can change ctx
        signal = is_valid ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        #~method end
        return signal, [ctx, flow_options]
      end
      #:circuit-interface-validate end

      step task: method(:validate)
    end
    #:circuit-interface-create end

    #:circuit-interface-call
    ctx          = {name: "Face to Face"}
    flow_options = {}

    signal, (ctx, _flow_options) = Create.([ctx, flow_options])

    signal #=> #<Trailblazer::Activity::End semantic=:success>
    ctx    #=> {:name=>\"Face to Face\", :validate_outcome=>true}
    #:circuit-interface-call end

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal '{:name=>"Face to Face", :validate_outcome=>true}'
  end

  # circuit interface: :start_task
  it do
    module B
      #:circuit-interface-start
      class Create < Trailblazer::Activity::Railway
        #~meths
        include T.def_steps(:create, :validate, :save)
        #~meths end
        step :create
        step :validate
        step :save
      end
      #:circuit-interface-start end

    end
    ctx             = {name: "Face to Face", seq: []}
    flow_options    = {}
    #:circuit-interface-start-call
    circuit_options = {
      start_task: Trailblazer::Activity::Introspect::Graph(B::Create).find { |node| node.id == :validate  }.task
    }

    signal, (ctx, flow_options) = B::Create.([ctx, flow_options], **circuit_options)
    #:circuit-interface-start-call end
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal '{:name=>"Face to Face", :seq=>[:validate, :save]}'
  end

  # circuit interface: :exec_context
  it do
    module C
      Memo = Struct.new(:name) do
        def save
          true
        end
      end

      #:circuit-interface-exec
      class Create < Trailblazer::Activity::Railway
        step :create
        step :save
      end
      #:circuit-interface-exec end

      #:circuit-interface-implementation
      class Create::Implementation
        def create(ctx, params:, **)
          ctx[:model] = Memo.new(params)
        end

        def save(ctx, model:, **)
          ctx[:model].save
        end
      end
    end
    #:circuit-interface-implementation end

    ctx             = {params: {name: "Face to Face"}}
    flow_options    = {}
    #:circuit-interface-exec-call
    circuit_options = {
      exec_context: C::Create::Implementation.new
    }

    signal, (ctx, flow_options) = C::Create.to_h[:circuit].([ctx, flow_options], **circuit_options)
    #:circuit-interface-exec-call end

    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    _(ctx.inspect).must_equal %{{:params=>{:name=>\"Face to Face\"}, :model=>#<struct DocsActivityTest::C::Memo name={:name=>\"Face to Face\"}>}}
  end
end
