require "test_helper"

class SubprocessTest < Minitest::Spec
  it do
    module A
      Memo = Class.new

      #:nested
      class Memo::Validate < Trailblazer::Activity::Railway
        step :check_params
        step :check_attributes
        #~methods
        include T.def_steps(:check_params, :check_attributes)
        #~methods end
      end
      #:nested end

      #:container
      class Memo::Create < Trailblazer::Activity::Railway
        step :create_model
        step Subprocess(Memo::Validate)
        step :save
        #~methods
        include T.def_steps(:create_model, :save)
        #~methods
      end
      #:container end

    end

    _signal, (ctx, _) = A::Memo::Create.([{seq: []}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

    _signal, (ctx, _) = A::Memo::Create.([{seq: [], check_params: false}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params], :check_params=>false}}

    module B
      Memo = Class.new
      Memo::Validate = A::Memo::Validate

      #:reconnect
      class Memo::Create < Trailblazer::Activity::Railway
        step :create_model
        step Subprocess(Memo::Validate), Output(:failure) => Track(:success)
        step :save
        #~methods
        include T.def_steps(:create_model, :save)
        #~methods end
      end
      #:reconnect end

    end
    signal, (ctx, _) = B::Memo::Create.([{seq: []}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

    signal, (ctx, _) = B::Memo::Create.([{seq: [], check_params: false}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params, :save], :check_params=>false}}
  end

  it do
    module C
      Memo = Class.new

      #:end-nested
      class Memo::Validate < Trailblazer::Activity::Railway
        step :check_params, Output(:failure) => End(:invalid_params)
        step :check_attributes
        #~methods
        include T.def_steps(:check_params, :check_attributes)
        #~methods end
      end
      #:end-nested end

      #:end
      class Memo::Create < Trailblazer::Activity::Railway
        step :create_model
        step Subprocess(Memo::Validate), Output(:invalid_params) => Track(:failure)
        step :save
        #~methods
        include T.def_steps(:create_model, :save)
        #~methods end
      end
      #:end end

    end

    _signal, (ctx, _) = C::Memo::Create.([{seq: []}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

    _signal, (ctx, _) = C::Memo::Create.([{seq: [], check_params: false}, {}])
    _(ctx.inspect).must_equal %{{:seq=>[:create_model, :check_params], :check_params=>false}}
  end

  it "subprocess automatically does not wire all termini of a nested activity, you need to configure it" do
    module D
      Memo = Class.new

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

    end

    # here we can see that failure, success, fail_fast and pass_fast has been wired
    assert_process_for D::Memo::Create, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => SubprocessTest::D::Memo::JustPassFast
SubprocessTest::D::Memo::JustPassFast
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
  end

#@ Subprocess(strict: true)
#  WARNING: this is experimental!
  module E
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
  end # E

  it "{strict: true} automatically wires all outputs" do
    # here we can see that failure, success, fail_fast and pass_fast has been wired

    assert_circuit E::Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => SubprocessTest::E::Song::Activity::Validate
SubprocessTest::E::Song::Activity::Validate
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

    assert_invoke E::Song::Activity::Create, seq: "[:create_model, :just_pass_fast]", terminus: :pass_fast
  end

  module F
    Song = Class.new

    module Song::Activity
      Validate = E::Song::Activity::Validate

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
  end # F

  it "{strict: true} allows overriding wiring manually" do
    assert_circuit F::Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => SubprocessTest::E::Song::Activity::Validate
SubprocessTest::E::Song::Activity::Validate
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
    assert_invoke F::Song::Activity::Create, seq: "[:create_model, :just_pass_fast, :save]"
    #@ However, Validate's {fail_fast} still goes to {End.fail_fast}.
    assert_invoke F::Song::Activity::Create, just_pass_fast: false, seq: "[:create_model, :just_pass_fast]", terminus: :fail_fast
  end

  module G
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
  end # G

  it "{strict: true} allows overriding wiring manually" do
    assert_circuit G::Song::Activity::Create, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*create_model>
<*create_model>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => SubprocessTest::G::Song::Activity::Validate
SubprocessTest::G::Song::Activity::Validate
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
    assert_invoke G::Song::Activity::Create, params: 408, seq: "[:create_model]", terminus: :fail_fast
    #@ success to success
    assert_invoke G::Song::Activity::Create, params: 200, seq: "[:create_model, :save]"
    #@ failure to failure
    assert_invoke G::Song::Activity::Create, params: nil, seq: "[:create_model]", terminus: :failure
  end
end
