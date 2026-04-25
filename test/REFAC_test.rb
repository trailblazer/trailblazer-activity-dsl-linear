require "test_helper"

class RefacTest < Minitest::Spec
  it "what" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model,
        In() => [:seq],
        Out() => [:model, :seq],
        Out() => :my_output ,
        In() => ->(ctx, params:, **) { {model: params.inspect} }

      # include T.def_steps(:model)
      def model(ctx, model:, seq:, **)
        # puts "@@@@@ #{model.inspect}"
        seq << :model
        ctx[:model] = model
      end

      def my_output(ctx, seq:, **)
        {
          captured_seq: seq.inspect
        }
      end
    end

    pp Trailblazer::Activity::TaskWrap.invoke(activity, {seq: [], params: []})

  end
end
