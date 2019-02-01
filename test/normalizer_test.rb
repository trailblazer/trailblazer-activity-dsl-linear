require "test_helper"

# Test the normalizer "activity".
# Here we simply run the normalizers and check if they generate the correct input hash (for the DSL).
class NormalizerTest < Minitest::Spec
  describe "Path" do
    let(:normalizer) do
      seq = Trailblazer::Activity::Path::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    let(:default_options) { {track_name: :success} }

    it "normalizer" do
      signal, (ctx, _) = normalizer.([**default_options])

      ctx.inspect.must_equal %{{:connections=>{:success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it "{after: :a} sets sequence_insert to [:Append, :a]" do
      signal, (ctx, _) = normalizer.([{**default_options, after: :a}])

      ctx.inspect.must_equal %{{:connections=>{:success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :after=>:a, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Append>, :a], :magnetic_to=>:success}}
    end

    it "{track_name: :random}" do
      signal, (ctx, _) = normalizer.([{**default_options, track_name: :upper_path}])

      ctx.inspect.must_equal %{{:connections=>{:success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :upper_path]}, :outputs=>{:success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:upper_path, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, "End.success"], :magnetic_to=>:upper_path}}
    end
  end

  let(:default_options) { {track_name: :success, left_track_name: :failure} }

  describe "Railway" do
    let(:normalizer) do
      seq = Trailblazer::Activity::Railway::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    let(:normalizer_for_fail) do
      seq = Trailblazer::Activity::Railway::DSL.normalizer_for_fail

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    let(:default_options) { {track_name: :success, left_track_name: :failure} }

    it "normalizer" do
      signal, (ctx, _) = normalizer.([{**default_options}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it "normalizer_for_fail" do
      signal, (ctx, _) = normalizer_for_fail.([{**default_options}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:failure}}
    end
  end

  describe "FastTrack" do
    let(:normalizer) do
      seq = Trailblazer::Activity::FastTrack::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    it " accepts :fast_track => true" do
      signal, (ctx, _) = normalizer.([{**default_options, fast_track: true}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :fast_track=>true, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it " accepts :pass_fast => true" do
      signal, (ctx, _) = normalizer.([{**default_options, pass_fast: true}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :pass_fast=>true, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it " accepts :fail_fast => true" do
      signal, (ctx, _) = normalizer.([{**default_options, fail_fast: true}])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :fail_fast=>true, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    it "goes without options" do
      signal, (ctx, _) = normalizer.([{**default_options, }])

      ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :success]}, :outputs=>{:failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:success}}
    end

    describe "normalizer_for_fail" do
      let(:normalizer_for_fail) do
        seq = Trailblazer::Activity::FastTrack::DSL.normalizer_for_fail

        process = compile_process(seq)
        circuit = process.to_h[:circuit]
      end

      it " accepts :fast_track => true" do
        signal, (ctx, _) = normalizer_for_fail.([{**default_options, fast_track: true}])

        ctx.inspect.must_equal %{{:connections=>{:failure=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :success=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :failure], :fail_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :fail_fast], :pass_fast=>[#<Method: Trailblazer::Activity::DSL::Linear::Search.Forward>, :pass_fast]}, :outputs=>{:pass_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::PassFast, semantic=:pass_fast>, :fail_fast=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::FastTrack::FailFast, semantic=:fail_fast>, :failure=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, :success=>#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>}, :track_name=>:success, :left_track_name=>:failure, :fast_track=>true, :sequence_insert=>[#<Method: Trailblazer::Activity::DSL::Linear::Insert.Prepend>, \"End.success\"], :magnetic_to=>:failure}}
      end
    end
  end

  describe "Activity-style normalizer" do
    let(:normalizer) do
      seq = Trailblazer::Activity::FastTrack::DSL.normalizer
      seq = Linear::Normalizer.activity_normalizer(seq)

      process = compile_process(seq)
      normalizer = process.to_h[:circuit]
    end

    let(:implementing) do
      implementing = Module.new do
        extend T.def_tasks(:a, :b, :c, :d, :f, :g)
      end
    end

    it "half-assed test" do


      def my_step_interface_builder(callable_with_step_interface)
        ->((ctx, flow_options), *) do
          ctx = callable_with_step_interface.(ctx, **ctx)
          return Trailblazer::Activity::Right, [ctx, flow_options]
        end
      end



      macro_hash = {task: implementing.method(:b)}

      signal, (ctx, _) = normalizer.(framework_options: default_options, options: implementing.method(:a), user_options: {step_interface_builder: method(:my_step_interface_builder)})

      ctx.keys.must_equal([:connections, :outputs, :track_name, :left_track_name, :task, :wrap_task, :step_interface_builder, :sequence_insert, :magnetic_to])  # step WrapMe, output: 1
pp ctx[:sequence_insert]

      # normalizer.(**default_options, options: macro_hash, )               # step task: Me, output: 1 (not using macro)
      # normalizer.(**default_options, options: macro_hash, user_options: {output: 1})         # step {task: Me}, output: 1   macro, user_opts
    end

    it "half-assed test for DSL options" do
      signal, (ctx, _) = normalizer.(
        framework_options:  default_options,
        options:            implementing.method(:a),
        user_options:       {step_interface_builder: Trailblazer::Activity::TaskBuilder.method(:Binary), Linear.Output(:success) => Linear.End(:new)}
      )

      ctx.keys.must_equal([:connections, :outputs, :track_name, :left_track_name, :task, :wrap_task, :step_interface_builder, :sequence_insert, :magnetic_to, :adds ])  # step WrapMe, output: 1
pp ctx[:sequence_insert]
    end

    it "macro hash can set user_options such as {fast_track: true}" do
      signal, (cfg, _) = normalizer.(framework_options: default_options, options: {fast_track: true}, user_options: {bla: 1})

      cfg.keys.must_equal [:connections, :outputs, :track_name, :left_track_name, :fast_track, :bla, :sequence_insert, :magnetic_to]
      cfg[:connections].keys.must_equal [:failure, :success, :fail_fast, :pass_fast]

  # insert a
      # FIXME: move this somewhere else
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence
      seq = Linear::DSL.insert_task(implementing.method(:a), sequence: seq, id: :a, **cfg)
      seq[1][3].must_equal({:id=>:a, :track_name=>:success, :left_track_name=>:failure, :fast_track=>true, :bla=>1})

  # insert b, before: :a
      # seq = Linear::DSL.insert_task(implementing.method(:b), sequence: seq, id: :b, **cfg)
      # seq[1][3].must_equal({:id=>:a, :fast_track=>true, :bla=>1})
    end

    it "user_options can override options" do
      signal, (cfg, _) = normalizer.(
        framework_options:  default_options,
        options:            {fast_track: true},
        user_options:       {bla: 1, fast_track: false}
      )

      cfg.keys.must_equal [:connections, :outputs, :track_name, :left_track_name, :fast_track, :bla, :sequence_insert, :magnetic_to]
      cfg[:connections].keys.must_equal [:failure, :success] # fast_track: false overrides the macro.

      # FIXME: move this somewhere else
      seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence
      seq = Linear::DSL.insert_task(implementing.method(:a), sequence: seq, id: :a, **cfg)
      seq[1][3].must_equal({:id=>:a, :track_name=>:success, :left_track_name=>:failure, :fast_track=>false, :bla=>1})
    end

    # Output => End
    # Output => Path() do ... end
    # :id => :a
    # :replace => :id
  end
end
