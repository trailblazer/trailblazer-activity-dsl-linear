require "test_helper"

class RailwayTest < Minitest::Spec
  Implementing = T.def_steps(:a, :b, :c, :d, :e, :f, :g)

  it "empty subclass" do
    path = Class.new(Activity::Railway) do
    end

    assert_circuit path, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    assert_call path
  end


  it "generic DSL" do
    activity = Class.new(Activity::Railway) do
      include Implementing
      step :a
      fail :b
      step :c
      pass :d
      fail :e
      step :f
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*c>
<*b>
 {Trailblazer::Activity::Left} => <*e>
 {Trailblazer::Activity::Right} => <*e>
<*c>
 {Trailblazer::Activity::Left} => <*e>
 {Trailblazer::Activity::Right} => <*d>
<*d>
 {Trailblazer::Activity::Left} => <*f>
 {Trailblazer::Activity::Right} => <*f>
<*e>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

#@ stay on right track
    assert_call activity, seq: "[:a, :c, :d, :f]"

#@ {:a} fails
    assert_call activity, terminus: :failure, seq: "[:a, :b, :e]", a: false

#@ {:b} fails
    assert_call activity, terminus: :failure, seq: "[:a, :b, :e]", a: false, b: false

#@ {:c} fails
    assert_call activity, terminus: :failure, seq: "[:a, :c, :e]", c: false

#@ {:d} fails
    assert_call activity, seq: "[:a, :c, :d, :f]", d: false

#@ {:e} fails
    assert_call activity, terminus: :failure, seq: "[:a, :c, :e]", c: false, e: false

#@ {:f} fails
    assert_call activity, terminus: :failure, seq: "[:a, :c, :d, :f]", f: false
  end

  describe "Activity::Railway" do

    it "allows {Output() => Track/Id}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        fail task: implementing.method(:a), id: :a, Output(:success) => Track(:success)
        step task: implementing.method(:g), id: :g
        step task: implementing.method(:c), id: :c
        fail task: implementing.method(:b), id: :b
        step task: implementing.method(:d), id: :d, Output(:failure) => Id(:b)
      end

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

    #@ right track
      assert_call activity, seq: %{[:f, :g, :c, :d]}

  # left track, {a} goes back to success
      assert_call activity, seq: "[:f, :a, :g, :c, :d]", f: Activity::Left, a: Activity::Right

  # left track, {a} stays on failure
      assert_call activity, seq: "[:f, :a, :b]", f: Activity::Left, a: Activity::Left, terminus: :failure

  # {d} goes to {b}
      assert_call activity, seq: "[:f, :g, :c, :d, :b]", d: Activity::Left, terminus: :failure
    end

    it "provides {pass}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c
        fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
      end

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      assert_call activity, seq: "[:f, :c, :g]"

  # pass returns false
      assert_call activity, c: Activity::Left, seq: "[:f, :c, :g]"
    end

    it "provides {pass} and allows {Output()}" do
      implementing = self.implementing

      activity = Class.new(Activity::Railway) do
        step task: implementing.method(:f), id: :f
        pass task: implementing.method(:c), id: :c, Output(:failure) => Id(:b)
        # fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
        step task: implementing.method(:b), id: :b
      end

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}

  # right track
      assert_call activity, seq: "[:f, :c, :g, :b]"

  # pass returns false
      assert_call activity, seq: "[:f, :c, :b]", c: Activity::Left
    end
  end



  it "fail: allows {Output() => Track()}" do
    activity = Class.new(Activity::Railway) do
      step :f
      pass :c, Output(:failure) => Id(:b)
      step :g
      step :b
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Left} => <*b>
 {Trailblazer::Activity::Right} => <*g>
<*g>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  it "accepts {:adds}" do
    activity = Class.new(Activity::Railway) do
      step :f, adds: [
        {row: Linear::Sequence::Row[:success, Implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {id: :g}], insert: [Linear::Insert.method(:Prepend), :f]}]
      fail :a, adds: [
        {row: Linear::Sequence::Row[:failure, Implementing.method(:b), [Linear::Search.Forward(Activity.Output("f/signal", :failure), :failure)], {}], insert: [Linear::Insert.method(:Prepend), :g]}]
    # seq = state.pass implementing.method(:f), id: :f, adds: [[[:success, implementing.method(:g), [Linear::Search.Forward(Activity.Output(Activity::Right, :success), :success)], {}], Linear::Insert.method(:Prepend), :f]]
    end

    assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: RailwayTest::Implementing.g>
#<Method: RailwayTest::Implementing.b>
 {f/signal} => <*a>
#<Method: RailwayTest::Implementing.g>
 {Trailblazer::Activity::Right} => <*f>
<*f>
 {Trailblazer::Activity::Left} => <*a>
 {Trailblazer::Activity::Right} => #<End/:success>
<*a>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
  end

  describe "Railway() builder: {:end_task}, {:failure_end}" do
    it "allows to define custom End instances" do
      MyFailure = Class.new(Activity::End)
      MySuccess = Class.new(Activity::End)

      activity = Activity::Railway(end_task: MySuccess.new(semantic: :my_success), failure_end: MyFailure.new(semantic: :my_failure)) do
        step task: T.def_task(:a)
      end

      _(activity.to_h[:outputs].inspect).must_equal %{[#<struct Trailblazer::Activity::Output signal=#<RailwayTest::MySuccess semantic=:my_success>, semantic=:my_success>, \
#<struct Trailblazer::Activity::Output signal=#<RailwayTest::MyFailure semantic=:my_failure>, semantic=:my_failure>]}

      assert_circuit activity, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<RailwayTest::MyFailure/:my_failure>
 {Trailblazer::Activity::Right} => #<RailwayTest::MySuccess/:my_success>
#<RailwayTest::MySuccess/:my_success>

#<RailwayTest::MyFailure/:my_failure>
}
    end
  end

end
