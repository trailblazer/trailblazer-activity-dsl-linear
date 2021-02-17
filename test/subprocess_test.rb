require "test_helper"

class SubprocessTest < Minitest::Spec
  it "" do
    implementing = self.implementing

    advance = Class.new(Activity::Path) do
      step :g
      step :f

      include T.def_steps(:g, :f)
    end

    controller = Class.new(Activity::Path) do
      step Subprocess(advance), id: :advance
      step :d

      include T.def_steps(:d)
    end

    my_controller = Class.new(Activity::Path) do
      step :c
      step Subprocess(controller), id: :controller

      include T.def_steps(:c)
    end

    our_controller = Class.new(Activity::Path) do
      step Subprocess(my_controller, patch: {[:controller, :advance] => -> { step implementing.method(:a), before: :f }}), id: :my_controller
    end

    whole_controller = Class.new(Activity::Path) do
      # patch our_controller itself
      step Subprocess(our_controller, patch: -> { step implementing.method(:b), after: :my_controller }), id: :our_controller
    end

# all existing activities are untouched

    oc = find(whole_controller, :our_controller)
    mc = find(our_controller, :my_controller)
     c = find(mc, :controller)
     a = find( c, :advance)

     assert_process_for advance, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for controller, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => <*d>
<*d>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for my_controller, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>
}

    assert_process_for our_controller, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>
}

    process = a.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    process = oc.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    # signal, (ctx, _) = my_controller.([{seq: []}])
    # ctx.inspect.must_equal %{{:seq=>[:c, :g, :f, :d]}}

    # signal, (ctx, _) = our_controller.([{seq: []}])
    signal, (ctx, _) = Trailblazer::Developer.wtf?(our_controller, [{seq: []}])
    _(ctx.inspect).must_equal %{{:seq=>[:c, :g, :a, :f, :d]}}
  end

  it "retains wirings in patched activity" do
    advance = Class.new(Activity::Railway) do
      step :g, Output(:failure) => End(:g_failure)
      step :f

      include T.def_steps(:g, :f)
    end

    controller = Class.new(Activity::Railway) do
      step Subprocess(advance), Output(:g_failure) => End(:g_failure), id: :advance
      step :d

      include T.def_steps(:d)
    end

    my_controller = Class.new(Activity::Railway) do
      step :c
      step Subprocess(controller, patch: { [:advance] => -> {} }), Output(:g_failure) => End(:g_failure)

      include T.def_steps(:c)
    end

    signal, (ctx, _) = Trailblazer::Developer.wtf?(my_controller, [{seq: [], g: false }])
    _(signal.inspect).must_equal %{#<Trailblazer::Activity::End semantic=:g_failure>}
    _(ctx.inspect).must_equal %{{:seq=>[:c, :g], :g=>false}}
  end

  def find(activity, id)
    Trailblazer::Activity::Introspect::Graph(activity).find(id).task
  end
end

class WithCustomSignalReturnedInSubprocess < Minitest::Spec
  it "wires additional custom output, no default" do
    Memo = Class.new
    InvalidParams = Class.new(Trailblazer::Activity::Signal)
    class Memo::Validate < Trailblazer::Activity::Railway
      step :validate, Output(InvalidParams, :invalid_params) => End(:invalid_params)
      include T.def_steps(:validate)
    end
    class Memo::Create < Trailblazer::Activity::Railway
      step :create_model
      step Subprocess(Memo::Validate),
        Output(:invalid_params) => Track(:invalid_params)
      step :handle_invalid_params, magnetic_to: :invalid_params
      step :save
      include T.def_steps(:create_model, :handle_invalid_params, :save)
    end
    signal, (ctx, _) = Memo::Create.(seq: [], validate: InvalidParams)
    _(ctx[:seq]).must_equal([:create_model, :validate, :handle_invalid_params, :save])
  end
end
