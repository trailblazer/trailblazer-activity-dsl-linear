require "test_helper"

class SubprocessTest < Minitest::Spec
  it "" do
    implementing = self.implementing

    advance = Class.new(Activity::Path) do
      step implementing.method(:g), id: :g
      step implementing.method(:f), id: :f
    end

    controller = Class.new(Activity::Path) do
      step Subprocess(advance), id: :advance
      step implementing.method(:d), id: :d
    end

    my_controller = Class.new(Activity::Path) do
      step implementing.method(:c), id: :c
      step Subprocess(controller), id: :controller
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
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for controller, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => <*#<Method: #<Module:0x>.d>>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    assert_process_for my_controller, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>
}

    process = a.to_h

    assert_process_for process, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    signal, (ctx, _) = my_controller.([{seq: []}])
    ctx.inspect.must_equal %{{:seq=>[:c, :g, :f, :d]}}

    signal, (ctx, _) = our_controller.([{seq: []}])
    ctx.inspect.must_equal %{{:seq=>[:c, :g, :a, :f, :d]}}
  end

  def find(activity, id)
    Trailblazer::Activity::Introspect::Graph(activity).find(id).task
  end
end
