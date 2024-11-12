require "test_helper"

class SubprocessTest < Minitest::Spec
  it "does not automatically connect outputs unknown to the Strategy (terminus :unknown)" do
    sub_activity = Class.new(Activity::Railway) do
      terminus :unknown
    end

    activity = Class.new(Activity::Railway) do
      terminus :unknown             # even though we have a terminus magnetic_to {:unknown}...
      step Subprocess(sub_activity) # ... only failure and success are connected.
    end

    assert_process_for activity, :success, :unknown, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<End/:unknown>

#<End/:failure>
}
  end

  # DISCUSS: maybe we can "soften" or un-strict this.
  it "fails when using {fast_track: true} with Path because it doesn't have the expected outputs" do
    exception = assert_raises do
      activity = Class.new(Activity::FastTrack) do
        step Subprocess(Activity::Path), fast_track: true
      end
    end

    assert_equal CU.inspect(exception.message), %(No `fail_fast` output found for Trailblazer::Activity::Path and outputs {:success=>#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=:success>, semantic=:success>})
  end

  it "{:outputs} provided by {Subprocess} is not overridden by step defaults" do
    sub_activity = Class.new(Activity::Path) do
    end

    # There is no {failure} connection because sub_activity is a Path.
    activity = Class.new(Activity::Railway) do
      step Subprocess(sub_activity)
    end

    assert_process_for activity, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Class:0x>
#<Class:0x>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<End/:failure>
}
  end

  # TODO: insert {strict: true} tests here.

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

    assert_invoke our_controller, seq: "[:c, :g, :a, :f, :d]"
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

    assert_invoke my_controller, g: false, terminus: :g_failure, seq: "[:c, :g]"
  end

  def find(activity, id)
    Trailblazer::Activity::Introspect::Nodes(activity, id: id).task
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

    signal, (ctx, _) = Memo::Create.([{seq: [], validate: InvalidParams}])
    ctx[:seq].must_equal([:create_model, :validate, :handle_invalid_params, :save])
  end
end

class SubprocessUnitTest < Minitest::Spec
  Memo = Class.new
  it "subprocess automatically does not wire all termini of a nested activity, you need to configure it" do
    #:end-pass-fast-nested
    class Memo::JustPassFast < Trailblazer::Activity::FastTrack
      step :just_pass_fast, pass_fast: true, fast_track: true
      include T.def_steps(:just_pass_fast)
      #~methods end
    end
    #:end-pass-fast-nested end

    #:end
    class Memo::Create < Trailblazer::Activity::FastTrack
      step :create_model
      step Subprocess(Memo::JustPassFast), fast_track: true
      step :save
      #~methods
      include T.def_steps(:create_model, :save)
      #~methods end
    end
    #:end end

    # here we can see that failure, success, fail_fast and pass_fast has been wired
    assert_process_for Memo::Create, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => SubprocessUnitTest::Memo::JustPassFast
SubprocessUnitTest::Memo::JustPassFast
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*save>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
  end
end

class Subprocess_Strict_UnitTest < Minitest::Spec
  #@ Subprocess(strict: true)
  #  WARNING: this is experimental!
  Song = Class.new

  module Song::Activity
    class Validate < Trailblazer::Activity::FastTrack
      #~meths
      step :just_pass_fast, pass_fast: true, fail_fast: true, fast_track: true
      include T.def_steps(:just_pass_fast)
      #~meths end
    end

    class Create < Trailblazer::Activity::FastTrack
      step :create_model
      step Subprocess(Validate, strict: true) # You don't need {fast_track: true} anymore.
      step :save
      #~meths
      include T.def_steps(:create_model, :save)
      #~meths end
    end
  end

  it "{strict: true} automatically wires all outputs" do
    # here we can see that failure, success, fail_fast and pass_fast has been wired

    assert_circuit Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => Subprocess_Strict_UnitTest::Song::Activity::Validate
Subprocess_Strict_UnitTest::Song::Activity::Validate
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*save>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

    assert_invoke Song::Activity::Create, seq: "[:create_model, :just_pass_fast]", terminus: :pass_fast
  end
end

class Subprocess_Strict2_UnitTest < Minitest::Spec
  Song = Class.new

  module Song::Activity
    Validate = Subprocess_Strict_UnitTest::Song::Activity::Validate

    class Create < Trailblazer::Activity::FastTrack
      step :create_model
      step Subprocess(Validate, strict: true),
        Output(:pass_fast) => Track(:success) # Provide your custom wiring if you don't like strict's.
      step :save
      #~meths
      include T.def_steps(:create_model, :save)
      #~meths end
    end
  end

  it "{strict: true} allows overriding wiring manually" do
    assert_circuit Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => Subprocess_Strict_UnitTest::Song::Activity::Validate
Subprocess_Strict_UnitTest::Song::Activity::Validate
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*save>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => <*save>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    #@ Validate's pass_fast goes to our success Track, we call {#save}.
    assert_invoke Song::Activity::Create, seq: "[:create_model, :just_pass_fast, :save]"
    #@ However, Validate's {fail_fast} still goes to {End.fail_fast}.
    assert_invoke Song::Activity::Create, just_pass_fast: false, seq: "[:create_model, :just_pass_fast]", terminus: :fail_fast
  end
end

class Subprocess_Terminus_UnitTest < Minitest::Spec
  Song = Class.new

  module Song::Activity
    class ValidationAPI
      def self.validate(params)
        params
      end
    end

    class Validate < Trailblazer::Activity::FastTrack
      Timeout = Class.new(Trailblazer::Activity::Signal)

      step :send_api_request,
        Output(Timeout, :timeout) => End(:http_timeout)
      #~meths
      def send_api_request(ctx, params:, **)
        status = ValidationAPI.validate(params)

        if status == 408
          return Timeout # returns a Signal subclass
        elsif status == 200
          return true # success track (per default)
        end

        return false # failure track (per default)
      end
      #~meths end
    end

    class Create < Trailblazer::Activity::FastTrack
      step :create_model
      step Subprocess(Validate, strict: true),
        Output(:http_timeout) => Track(:fail_fast) # Provide your custom wiring if you don't like strict's.
      step :save
      #~meths
      include T.def_steps(:create_model, :save)
      #~meths end
    end
  end

  it "{strict: true} allows overriding wiring manually" do
    assert_circuit Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => Subprocess_Terminus_UnitTest::Song::Activity::Validate
Subprocess_Terminus_UnitTest::Song::Activity::Validate
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => <*save>
 {#<Trailblazer::Activity::End semantic=:http_timeout>} => #<End/:fail_fast>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
 {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    #@ Follow {http_timeout} to fail_fast.
    assert_invoke Song::Activity::Create, params: 408, seq: "[:create_model]", terminus: :fail_fast
    #@ success to success
    assert_invoke Song::Activity::Create, params: 200, seq: "[:create_model, :save]"
    #@ failure to failure
    assert_invoke Song::Activity::Create, params: nil, seq: "[:create_model]", terminus: :failure
  end

end
