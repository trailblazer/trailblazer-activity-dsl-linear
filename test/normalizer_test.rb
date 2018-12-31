require "test_helper"

# Test the normalizer "activity".
# Here we simply run the normalizers and check if they generate the correct input hash (for the DSL).
class NormalizerTest < Minitest::Spec
  describe "FastTrack" do
    let(:normalizer) do
      seq = Trailblazer::Activity::FastTrack::DSL.normalizer

      process = Linear::Compiler.(seq)
      circuit = process.to_h[:circuit]
    end

    it " accepts :fast_track => true" do
      signal, (ctx, _) = normalizer.([{user_options: {fast_track: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fast_track=>true}, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it " accepts :pass_fast => true" do
      signal, (ctx, _) = normalizer.([{user_options: {pass_fast: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:pass_fast=>true}, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it " accepts :fail_fast => true" do
      signal, (ctx, _) = normalizer.([{user_options: {fail_fast: true}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fail_fast=>true}, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it "goes without options" do
      signal, (ctx, _) = normalizer.([{user_options: {}}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{}, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    describe "normalizer_for_fail" do
      let(:normalizer_for_fail) do
        seq = Trailblazer::Activity::FastTrack::DSL.normalizer_for_fail

        process = Linear::Compiler.(seq)
        circuit = process.to_h[:circuit]
      end

      it " accepts :fast_track => true" do
        signal, (ctx, _) = normalizer_for_fail.([{user_options: {fast_track: true}}])

        ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :user_options=>{:fast_track=>true}, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:failure}}
      end
    end
  end
end
