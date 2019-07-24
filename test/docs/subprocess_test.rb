require "test_helper"

class SubprocessTest < Minitest::Spec
  it do
    module A
      Memo = Class.new

      class Memo::Validate < Trailblazer::Activity::Railway
        step :check_params
        step :check_attributes

        include T.def_steps(:check_params, :check_attributes)
      end

      class Memo::Create < Trailblazer::Activity::Railway
        step :create_model
        step Subprocess(Memo::Validate)
        step :save

        include T.def_steps(:create_model, :save)
      end

      signal, (ctx, _) = Memo::Create.([{seq: []}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

      signal, (ctx, _) = Memo::Create.([{seq: [], check_params: false}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params], :check_params=>false}}
    end

    module B
      Memo = Class.new
      Memo::Validate = A::Memo::Validate

      class Memo::Create < Trailblazer::Activity::Railway
        step :create_model
        step Subprocess(Memo::Validate), Output(:failure) => Track(:success)
        step :save

        include T.def_steps(:create_model, :save)
      end

      signal, (ctx, _) = Memo::Create.([{seq: []}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

      signal, (ctx, _) = Memo::Create.([{seq: [], check_params: false}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :save], :check_params=>false}}
    end
  end

end
