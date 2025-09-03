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

  it "a {TaskWrap::Extension} can reference {call_task} because it's the first Extension when compiling" do
    add_1 = method(:add_1)

    activity = Class.new(Activity::Railway) do
      step :model,
        Extension() => Trailblazer::Activity::TaskWrap.Extension([add_1, id: "user.add_1",
          prepend: "task_wrap.call_task"] # the {task_wrap.call_task} step is present.
        )
      include T.def_steps(:model)
    end

    assert_invoke activity, seq: "[1, :model]"
  end

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

  it "you can pass {:normalizer_extensions} explicitly. Why? i'm not sure yet" do
    # NOTE: this is @private API, don't use it and then later complain! :*
    my_normalizer_ext = Activity::DSL::Linear::Normalizer.Extension(method(:my_normalizer_extension))

    activity = Class.new(Activity::Railway) do
      step :model,
        normalizer_extensions: [*Activity::DSL::Linear::Strategy::INITIAL_NORMALIZER_EXTENSIONS, my_normalizer_ext]

      def model(ctx, model:, **)
        ctx[:ctx_in_model] = CU.inspect(ctx.inspect)
        ctx[:seq] << :model
      end
    end

    # We can add to the data hash, just as an example.
    assert_equal Activity::Introspect::Nodes(activity, id: :model).data[:my_variable], %(:model)

    # In model, we only see {:model, :seq}.
    assert_invoke activity, bogus: true, seq: "[1, :model]", expected_ctx_variables: {ctx_in_model: %(#<Trailblazer::Context::Container wrapped_options={:model=>nil, :seq=>[1]} mutable_options={}>)}
  end

  it "accepts {Extension}s along with {In()} and other additional extensions" do
    ext_prepend = ext_prepend()

    activity = Class.new(Activity::Path) do
      # Extension() doesn't overwrite In() and vice-versa!
      step :model,
        Extension() => Trailblazer::Activity::TaskWrap.Extension(ext_prepend), # this is placed first in the taskWrap, because I/O merges into non_symbol_options last.
        In() =>     ->(ctx, *) { {seq: ctx[:seq] += [:input]} }
      step :save

      include T.def_steps(:model, :save)
    end

    assert_invoke activity, seq: "[1, :input, :model, :save]"
  end

  describe "Extension() can define an order for compilation time" do
    it "it automatically works if they're added in the right order" do
      ext_prepend, ext_append = ext_prepend(), ext_append()

      my_referencing_ext = Trailblazer::Activity::TaskWrap.Extension([method(:add_2), id: "user.add_2", prepend: "user.add_1"]) # we're referencing another tw step here.

      activity = Class.new(Activity::Railway) do
        step :model,
          Extension() => Trailblazer::Activity::TaskWrap.Extension(ext_prepend), # this adds a tw step named "user.add_1"
          Extension() => my_referencing_ext

        include T.def_steps(:model)
      end

      assert_invoke activity, seq: "[2, 1, :model]"
    end

    it "you can reference IDs of left Extension()" do
      ext_prepend, ext_append = ext_prepend(), ext_append()

      my_referencing_ext = Trailblazer::Activity::TaskWrap.Extension([method(:add_2), id: "user.add_2", prepend: "user.add_1"]) # we're referencing another tw step here.

      activity = Class.new(Activity::Railway) do
        step :model,
          Extension(append: :SECOND_IN_LINE) => my_referencing_ext, # this Extension would normally be evaluated before the next.
          Extension(id: :SECOND_IN_LINE) => Trailblazer::Activity::TaskWrap.Extension(ext_prepend) # this adds a tw step named "user.add_1" which is referenced in the tw ext above.

        include T.def_steps(:model)
      end

      assert_invoke activity, seq: "[2, 1, :model]"
    end
  end

  describe "#Subprocess" do
    let(:sub_activity) do
      my_normalizer_ext = Activity::DSL::Linear::Normalizer.Extension(method(:my_normalizer_extension))

      Class.new(Activity::Railway) do
        step :model

        def model(ctx, model:, **)
          ctx[:ctx_in_model] = CU.inspect(ctx.inspect)
          ctx[:seq] << :model
        end

        @state.update!(:fields) do |fields|
          fields.merge(
            normalizer_extensions: fields[:normalizer_extensions] + [my_normalizer_ext]
          )
        end
      end
    end

    it "with Subprocess(), it grabs {:normalizer_extensions} automatically" do
      sub_activity = sub_activity()

      activity = Class.new(Activity::Railway) do
        step Subprocess(sub_activity), id: :sub # here, we "inherit" settings from sub's {:normalizer_extensions}.
      end

      # Nested OPs can tweak the options how they're added via {#step} in the outer OP.
      assert_equal Activity::Introspect::Nodes(activity, id: :sub).data[:my_variable], %(:sub)
      assert_invoke activity, bogus: true, seq: "[1, :model]", expected_ctx_variables: {ctx_in_model: %(#<Trailblazer::Context::Container wrapped_options={:model=>nil, :seq=>[1]} mutable_options={}>)}
    end

    it "also allows mixing {:normalizer_extensions} and other DSL options" do
      sub_activity = sub_activity()

      activity = Class.new(Activity::Railway) do
        step Subprocess(sub_activity),
          id: :sub,
          In() => [:current_user] # this mixes with the other options from sub_activity's {:normalizer_extensions} field.
      end

      # Nested OPs can tweak the options how they're added via {#step} in the outer OP.
      assert_equal Activity::Introspect::Nodes(activity, id: :sub).data[:my_variable], %(:sub)
      assert_invoke activity, bogus: true, seq: "[1, :model]", expected_ctx_variables: {ctx_in_model: %(#<Trailblazer::Context::Container wrapped_options={:current_user=>nil, :model=>nil, :seq=>[1]} mutable_options={}>)}
    end
  end

  describe "{inherit: true}" do
    it "accepts Extension(generic: true) which mean the Extension call is not inherited with {inherit: true}" do
      ext_prepend, ext_append = ext_prepend(), ext_append()

      activity = Class.new(Activity::Path) do
        step :model,
          Extension(is_generic: true) => Trailblazer::Activity::TaskWrap.Extension(ext_append), # *not* inherited to {sub_activity}.
          Extension()                 => Trailblazer::Activity::TaskWrap.Extension(ext_prepend)
        step :save

        include T.def_steps(:model, :save)
      end

      inheriting_activity = Class.new(activity) do
        step :create_model,
          inherit: true, replace: :model

        include T.def_steps(:create_model)
      end

      # require "trailblazer/developer"
      # puts Trailblazer::Developer.render(inheriting_activity)
      # node, activity, _  = Trailblazer::Developer::Introspect.find_path(inheriting_activity, [:model])
      # pipe = Trailblazer::Developer::Render::TaskWrap.render_for(inheriting_activity, node)
      # puts pipe

      assert_invoke activity, seq: "[1, :model, 2, :save]"
      assert_invoke inheriting_activity, seq: "[1, :create_model, :save]"
    end

    # this basically tests the {is_generic: true} in {Strategy::INITIAL_NORMALIZER_EXTENSIONS}.
    it "{inherit: true} works with {Subprocess()}" do
      model = Class.new(Activity::Railway) do
        step :model
        include T.def_steps(:model)
      end

      activity = Class.new(Activity::Railway) do
        step Subprocess(model), id: :model
      end

      validate = Class.new(Activity::Railway) do
        step :validate
        include T.def_steps(:validate)
      end

      inheriting_activity = Class.new(activity) do
        step Subprocess(validate), inherit: true, replace: :model
      end

      assert_invoke activity, seq: "[:model]"
      assert_invoke inheriting_activity, seq: "[:validate]"
    end
  end
end
