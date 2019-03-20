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

  describe "Activity::FastTrack" do

    it "provides defaults" do
      implementing = self.implementing

      activity = Class.new(Activity::FastTrack) do
        step task: implementing.method(:f), id: :f
        fail task: implementing.method(:a), id: :a
        step task: implementing.method(:g), id: :g
        step task: implementing.method(:c), id: :c
        fail task: implementing.method(:b), id: :b
        step task: implementing.method(:d), id: :d
      end

      process = activity.to_h

      assert_process_for process, :success, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
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
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

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
    end
  end


    # normalizer
end
