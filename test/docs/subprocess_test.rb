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

      signal, (ctx, _) = Memo::Create.([{seq: []}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

      signal, (ctx, _) = Memo::Create.([{seq: [], check_params: false}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params], :check_params=>false}}
    end

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

      signal, (ctx, _) = Memo::Create.([{seq: []}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

      signal, (ctx, _) = Memo::Create.([{seq: [], check_params: false}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :save], :check_params=>false}}
    end
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

      signal, (ctx, _) = Memo::Create.([{seq: []}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params, :check_attributes, :save]}}

      signal, (ctx, _) = Memo::Create.([{seq: [], check_params: false}, {}])
      ctx.inspect.must_equal %{{:seq=>[:create_model, :check_params], :check_params=>false}}
    end
  end

  it "subprocess automatically wires all termini of a nested activity" do
    module D
      Memo = Class.new

      #:end-nested
      class Memo::JustPassFast < Trailblazer::Activity::FastTrack
        step :just_pass_fast, pass_fast: true, fast_track: true
        include T.def_steps(:just_pass_fast)
        #~methods end
      end
      #:end-nested end

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
      expected_wiring = "
        SubprocessTest::D::Memo::JustPassFast
          {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
          {#<Trailblazer::Activity::End semantic=:success>} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=save>
          {#<Trailblazer::Activity::End semantic=:fail_fast>} => #<End/:fail_fast>
          {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:pass_fast>
      ".gsub(/\s+/, "")

      Trailblazer::Developer::Render::Circuit.(Memo::Create).gsub(/\s+/, "")
        .must_include(expected_wiring)
    end
  end
end
