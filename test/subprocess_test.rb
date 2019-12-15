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
      step Subprocess(my_controller, [:controller, :advance], -> { step implementing.method(:a), before: :f }), id: :my_controller
    end


# all existing activities are untouched

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

    # signal, (ctx, _) = my_controller.([{seq: []}])
    # ctx.inspect.must_equal %{{:seq=>[:c, :g, :f, :d]}}

    # signal, (ctx, _) = our_controller.([{seq: []}])
    signal, (ctx, _) = Trailblazer::Developer.wtf?(our_controller, [{seq: []}])
    ctx.inspect.must_equal %{{:seq=>[:c, :g, :a, :f, :d]}}
  end

  def find(activity, id)
    Trailblazer::Activity::Introspect::Graph(activity).find(id).task
  end
end
