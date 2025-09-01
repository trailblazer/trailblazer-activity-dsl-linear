require "test_helper"

# Test Extension() and the internal `ctx[:extensions]` field.
class ExtensionsTest < Minitest::Spec
  it "per default, {:task_wrap} comes from Strategy and adds {call_task}" do
    activity = Class.new(Activity::Railway) do
      step :model

      include T.def_steps(:model)
    end

    assert_invoke activity, seq: "[:model]"
  end

  let(:ext_prepend) { [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"] }
  let(:ext_append) { [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"] }

  it "Extension() => TaskWrap::Extension() allows adding steps to the default {:task_wrap}" do
    ext_prepend, ext_append = ext_prepend(), ext_append()

    activity = Class.new(Activity::Railway) do
      step :model,
        Extension() => Trailblazer::Activity::TaskWrap.Extension(ext_prepend),
        Extension() => Trailblazer::Activity::TaskWrap.Extension(ext_append)
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :model, 2, :save]"
  end

  it "you can pass {:normalizer_extensions} explicitely. Why? i'm not sure yet" do
    # ext_prepend, ext_append = ext_prepend(), ext_append()

    def my_normalizer_extension(ctx, id:, non_symbol_options:, **)
      ctx.merge!(
        my_variable: id.inspect,
        non_symbol_options: non_symbol_options.merge(
          Activity::Railway.In() => [:model],
          Activity::Railway.Inject() => [:seq],
          Activity::Railway.Extension() => Activity::TaskWrap.Extension(ext_prepend),
          Activity::Railway.DataVariable() => :my_variable
        )
      )
    end

    my_normalizer_ext = Activity::DSL::Linear::Normalizer.Extension(method(:my_normalizer_extension))

    activity = Class.new(Activity::Railway) do
      step :model,
        normalizer_extensions: [my_normalizer_ext]
      # step :save

      def model(ctx, model:, **)
        ctx[:ctx_in_model] = ctx.inspect
        ctx[:seq] << :model
      end
    end

    # We can add to the data hash, just as an example.
    assert_equal Activity::Introspect::Nodes(activity, id: :model).data[:my_variable], %(:model)

    assert_invoke activity, seq: "[1, :model]", expected_ctx_variables: {ctx_in_model: %(#<Trailblazer::Context::Container wrapped_options={:model=>nil, :seq=>[1]} mutable_options={}>)}
  end




  it "accepts Extension() => Normalizer(task_wrap: true)" do
    test = self

    activity = Class.new(Activity::Path) do
      step :model,
        Extension() => test.suffix_1_extension,
        Extension() => test.prepend_1_extension
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :model, 1, :save]"
  end

  it "accepts {Extension}s along with {In()} and other additional extensions" do
    add_1_extension = prepend_1_extension

    activity = Class.new(Activity::Path) do
      # Extension() doesn't overwrite In() and vice-versa!
      step :model,
        Extension() => add_1_extension,
        In() =>     ->(ctx, *) { {seq: ctx[:seq] += [:input]} }
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[:input, 1, :model, :save]"
  end


  it "accepts Extension(generic: true) which is not inherited with {inherit: true}" do
    test = self

    activity = Class.new(Activity::Path) do
      step :model,
        Extension(is_generic: true) => test.suffix_1_extension, # *not* inherited to {sub_activity}.
        Extension()                 => test.prepend_1_extension
      step :save

      include T.def_steps(:model, :save)
    end

    sub_activity = Class.new(activity) do
      step :create_model,
        inherit: true, replace: :model

      include T.def_steps(:create_model)
    end

    assert_invoke activity, seq: "[1, :model, 1, :save]"
    assert_invoke sub_activity, seq: "[1, :create_model, :save]"
    # assert_equal activity.to_h[:sequence][1].data[:extensions][0], %{}
  end
end
