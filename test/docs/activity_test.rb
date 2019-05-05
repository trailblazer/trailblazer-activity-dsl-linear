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

        module D
          module Memo; end
          #:task-implementation
          class Memo::Create < Trailblazer::Activity::Railway
            def self.authorize(ctx, **)
              #~method
              if current_user.can?(Memo, :create)
                true
              else
                false
              end
              #~method end
            end

            step method(:authorize)
            # ...
          end
          #:task-implementation end
        end # D
      end # A

      signal, (ctx, flow_options) = A::Memo::Create.([{current_user: user}, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}

      signal, (ctx, flow_options) = A::B::Memo::Create.([{current_user: user}, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}

      signal, (ctx, flow_options) = A::C::Memo::Create.([{current_user: user}, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}

      signal, (ctx, flow_options) = A::D::Memo::Create.([{current_user: user}, {}])
      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
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
=begin
      #:overview-result
      pp ctx #=>
      {:id=>1,
       :params=>{:body=>"Awesome!"},
       :model=>#<struct DocsActivityTest::Memo body=nil>,
       :errors=>"body not long enough"}

      puts signal #=> #<Trailblazer::Activity::End semantic=:validation_error>
      #:overview-result end
=end
      ctx.inspect.must_equal '{:id=>1, :params=>{:body=>"Awesome!"}, :model=>#<struct DocsActivityTest::Memo body=nil>, :errors=>"body not long enough"}'

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

    signal, (ctx, flow_options) = Create.([ctx, flow_options], {})

    signal #=> #<Trailblazer::Activity::End semantic=:success>
    ctx    #=> {:name=>\"Face to Face\", :validate_outcome=>true}
    #:circuit-interface-call end

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal '{:name=>"Face to Face", :validate_outcome=>true}'
  end
end
