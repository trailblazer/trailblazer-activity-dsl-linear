require "test_helper"

class DocsMacroTest < Minitest::Spec
  it "what" do
    module A
      #:macro
      module MyMacro
        def self.NormalizeParams(name: :myparams, merge_hash: {})
          task = ->((ctx, flow_options), _) do
            ctx[name] = ctx[:params].merge(merge_hash)

            return Trailblazer::Activity::Right, [ctx, flow_options]
          end

          # new API
          {
            task: task,
            id:   name
          }
        end
      end
      #:macro end

      #:macro-call
      class Create < Trailblazer::Activity::Railway
        step MyMacro::NormalizeParams(merge_hash: {role: "sailor"})
      end
      #:macro-call end
    end

    signal, (ctx, _) = A::Create.([{params: {user: "Adam"}}, {}])

    ctx.inspect.must_equal %{{:params=>{:user=>\"Adam\"}, :myparams=>{:user=>\"Adam\", :role=>\"sailor\"}}}
  end

  it "what" do
    module B
      class User < Struct.new(:id)
        def self.find_by(id:)
          id && new(id)
        end
      end

      #:output
      module MyMacro
        def self.FindModel(model_class)
          # the inserted task.
          task = ->((ctx, flow_options), _) do
            model         = model_class.find_by(id: ctx[:params][:id])

            return_signal = model ? Trailblazer::Activity::Right : Trailblazer::Activity::Left
            ctx[:model]   = model

            return return_signal, [ctx, flow_options]
          end

          # the configuration needed by Trailblazer's DSL.
          {
            task: task,
            id:   :"find_model_#{model_class}",
            Trailblazer::Activity::Railway.Output(:failure) => Trailblazer::Activity::Railway.End(:not_found)
          }
        end
      end
      #:output end

      #:output-usage
      class Create < Trailblazer::Activity::Railway
        step MyMacro::FindModel(User)
      end
      #:output-usage end
    end

    signal, (ctx, _) = B::Create.([{params: {id: 1}}, {}])
    ctx.inspect.must_equal %{{:params=>{:id=>1}, :model=>#<struct DocsMacroTest::B::User id=1>}}
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}

    signal, (ctx, _) = Trailblazer::Developer.wtf?(B::Create, [{params: {}}])
    ctx.inspect.must_equal %{{:params=>{}, :model=>nil}}
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:not_found>}

=begin
#:output-result
signal, (ctx, _) = Trailblazer::Developer.wtf?(User::Create, [{params: {id: nil}}])
signal #=> #<Trailblazer::Activity::End semantic=:not_found>

`-- User::Create
    |-- Start.default
    |-- find_model_User
    `-- End.not_found
#:output-result end
=end
  end
end
