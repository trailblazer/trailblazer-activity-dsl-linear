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
end
