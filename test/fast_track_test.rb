require "test_helper"

class FastTrackTest < Minitest::Spec
  it "#initial_sequence" do
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence(
        initial_sequence: Trailblazer::Activity::Railway::DSL.initial_sequence(
          initial_sequence: Trailblazer::Activity::Path::DSL.initial_sequence(track_name: :success, end_task: Activity::End.new(semantic: :success), end_id: "End.success"),
          failure_end: Activity::End.new(semantic: :failure)
        )
      )

      Cct(compile_process(seq)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
    end

    it "allows overriding all 4 ends" do
      raise
    end


  describe "Activity::FastTrack" do

    it "provides defaults" do
      implementing = T.def_steps(:f, :a, :g, :c, :b, :d)

      activity = Class.new(Activity::FastTrack) do
        step implementing.method(:f), id: :f
        fail implementing.method(:a), id: :a
        step implementing.method(:g), id: :g
        step implementing.method(:c), id: :c, fast_track: true
        fail implementing.method(:b), id: :b
        step implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.c>>
<*#<Method: #<Module:0x>.c>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

  # right track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c, :d]}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a, :b], :f=>false}}

  # left track
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :b], :g=>false}}

  # c --> pass_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Trailblazer::Activity::FastTrack::PassFast}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c], :c=>Trailblazer::Activity::FastTrack::PassFast}}

  # c --> fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], c: Trailblazer::Activity::FastTrack::FailFast}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g, :c], :c=>Trailblazer::Activity::FastTrack::FailFast}}

    end

    it "provides {:pass_fast} and {:fail_fast}" do
      implementing = T.def_steps(:f, :a, :g, :c, :b, :d)

      activity = Class.new(Activity::FastTrack) do
        step implementing.method(:f), id: :f
        fail implementing.method(:a), id: :a, fail_fast: true
        step implementing.method(:g), id: :g, pass_fast: true, fail_fast: true
        # step implementing.method(:c), id: :c, fail_fast: true, pass_fast: true
        fail implementing.method(:b), id: :b
        step implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :pass_fast, :fail_fast, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Left} => <*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.g>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.g>>
 {Trailblazer::Activity::Left} => #<End/:fail_fast>
 {Trailblazer::Activity::Right} => #<End/:pass_fast>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
<*#<Method: #<Module:0x>.d>>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

  # g --> :pass_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: []}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:pass_fast>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g]}}

  # a --> :failure
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:failure>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a, :b], :f=>false}}

  # a --> :fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], f: false, a: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :a], :f=>false, :a=>false}}

  # g --> :fail_fast
      signal, (ctx, _) = process.to_h[:circuit].([{seq: [], g: false}])

      signal.inspect.must_equal  %{#<Trailblazer::Activity::End semantic=:fail_fast>}
      ctx.inspect.must_equal     %{{:seq=>[:f, :g], :g=>false}}
    end
  end


    # normalizer
end
