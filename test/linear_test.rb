require "test_helper"

#:intermediate
  def a(x=1)
  end
#:intermediate end

class LinearTest < Minitest::Spec
  Right = Class.new#Trailblazer::Activity::Right
  Left = Class.new#Trailblazer::Activity::Right
  PassFast = Class.new#Trailblazer::Activity::Right

  # Process = Trailblazer::Activity::Process
  # Inter = Trailblazer::Activity::Process::Intermediate
  # Activity = Trailblazer::Activity


  # let(:implementing) do
  #   implementing = Module.new do
  #     extend T.def_tasks(:a, :b, :c, :d, :f, :g)
  #   end
  #   implementing::Start = Activity::Start.new(semantic: :default)
  #   implementing::Failure = Activity::End(:failure)
  #   implementing::Success = Activity::End(:success)

  #   implementing
  # end

  # outputs = task.outputs / default

          # default #step
      # :success=>[Right, :success]=>[Search.method(:Forward), :success]
          # override by user
      # :success=>[Right, :success]=>[Search.method(:ById), :blaId]

  # default {step}: Output(outputs[:success].signal, outputs[:success].semantic)=>[Search::Forward, :success], ...
  # compile effective Output(signal, semantic) => Search::<strat>


  # pass_fast: true => outputs+=PassFast, connections+=PassFast
  # id, taskBuilder
  # process_DSL_options Output/Task()

# step
  # normalize (e.g. macro/task)
  # step (original)
  #   PASSFAST::step extending args
  # insert_task...

=begin
Railway.step(my_step_pipeline:Railway.step_pipe)
  my_step_pipeline.(..)
  insert_task

FastTrack.step(my=Railway.step_pipe+..)

=end


  describe "FastTrack" do
    let(:normalizer) do
      seq = Trailblazer::Activity::FastTrack::DSL.normalizer

      process = compile_process(seq)
      circuit = process.to_h[:circuit]
    end

    describe "normalizer_for_fail" do
      let(:normalizer_for_fail) do
        seq = Trailblazer::Activity::FastTrack::DSL.normalizer_for_fail

        process = compile_process(seq)
        circuit = process.to_h[:circuit]
      end

      it "PROTOTYPING step" do
        default_options = {track_name: :success, left_track_name: :failure}

        signal, (ctx, _) = normalizer.([{fast_track: true, **default_options}])
        step_options = ctx

        signal, (ctx, _) = normalizer_for_fail.([{**default_options}])
        fail_options = ctx

        # a stateful "DSL object" will keep {seq}
        seq = Trailblazer::Activity::FastTrack::DSL.initial_sequence
        seq = Linear::DSL.insert_task(seq, task: implementing.method(:a), id: :a, **step_options)
        seq = Linear::DSL.insert_task(seq, task: implementing.method(:b), id: :b, **fail_options)

        process = compile_process(seq)
        cct = Cct(process: process)



        state = Linear::DSL.State(Activity::FastTrack)
        state.step implementing.method(:a), id: :a, fast_track: true
  seq = state.fail implementing.method(:b), id: :b

        process = compile_process(seq)
        cct = Cct(process: process)


        cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:fail_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}

        state = Linear::DSL.State(Activity::FastTrack, )
        state.step implementing.method(:a), id: :a, fast_track: true, Linear.Output(:fail_fast) => Linear.Track(:pass_fast)
  seq = state.step implementing.method(:b), id: :b, Linear.Output(:success) => Linear.Id(:a)
  seq = state.step implementing.method(:c), id: :c, Linear.Output(:success) => Linear.End(:new)
  seq = state.fail implementing.method(:d), id: :d#, Linear.Output(:success) => Linear.End(:new)
# pp seq
        process = compile_process(seq)
        cct = Cct(process: process)


        cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::FastTrack::FailFast} => #<End/:pass_fast>
 {Trailblazer::Activity::FastTrack::PassFast} => #<End/:pass_fast>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:new>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:failure>
#<End/:success>

#<End/:new>

#<End/:pass_fast>

#<End/:fail_fast>

#<End/:failure>
}
      end

      it "breaks with not-yet existing reference" do
        state = Linear::DSL.State(Activity::FastTrack, )

        # seq = state.step implementing.method(:a), id: :a
        seq = state.step implementing.method(:b), id: :b, Linear.Output(:success) => Linear.Id(:a)
# TODO: fix me, of course
assert_raises do
        process = compile_process(seq)
end
        # cct = Cct(process: process)

        # cct.must_equal %{}
      end

      it "Path()" do
        path_end = Activity::End.new(semantic: :roundtrip)

        state = Activity::Railway::DSL::State.new(Activity::Railway::DSL.OptionsForState)
        state.step( implementing.method(:a), id: :a, fast_track: true, Linear.Output(:fail_fast) => Linear.Path(end_task: path_end) do |path|
          path.step implementing.method(:f), id: :f
          path.step implementing.method(:g), id: :g
        end
        )
        state.step implementing.method(:b), id: :b, Linear.Output(:success) => Linear.Id(:a)
        state.step implementing.method(:c), id: :c, Linear.Output(:success) => Linear.End(:new)
        state.fail implementing.method(:d), id: :d#, Linear.Output(:success) => Linear.End(:new)
# pp seq
        # process = compile_process(seq)
        # cct = Cct(process: process)


        assert_process seq, :success, :failure, :roundtrip, %{

}

      end
    end
  end


  def default_binary_outputs
    {success: Activity::Output(Activity::Right, :success), failure: Activity::Output(Activity::Left, :failure)}
  end

  def default_step_connections
    {success: [Linear::Search.method(:Forward), :success], failure: [Linear::Search.method(:Forward), :failure]}
  end

  def step(task, sequence:, magnetic_to: :success, outputs: self.default_binary_outputs, connections: self.default_step_connections, sequence_insert: [Linear::Insert.method(:Prepend), "End.success"], **local_options)
    # here, we want the final arguments.
    Linear::DSL.insert_task(sequence, task: task, magnetic_to: magnetic_to, outputs: outputs, connections: connections, sequence_insert: sequence_insert, **local_options)
  end

  # fail simply wires both {:failure=>} and {:success=>} outputs to the next {=>:failure} task.
  def fail(task, magnetic_to: :failure, connections: default_step_connections.merge(success: default_step_connections[:failure]), **local_options)
    step(task, magnetic_to: magnetic_to, connections: connections, **local_options)
  end

  let(:sequence) do
    start_default = Activity::Start.new(semantic: :default)
    end_success   = Activity::End.new(semantic: :success)
    end_failure   = Activity::End.new(semantic: :failure)

    start_event = Linear::DSL.create_row(task: start_default, id: "Start.default", magnetic_to: nil, outputs: {success: default_binary_outputs[:success]}, connections: {success: default_step_connections[:success]})
    @sequence   = Linear::Sequence[start_event]

    end_args = {sequence_insert: [Linear::Insert.method(:Append), "Start.default"]}

    @sequence = step(end_failure, sequence: @sequence, magnetic_to: :failure, id: "End.failure", outputs: {failure: end_failure}, connections: {failure: [Linear::Search.method(:Noop)]}, **end_args)
    @sequence = step(end_success, sequence: @sequence, magnetic_to: :success, id: "End.success", outputs: {success: end_success}, connections: {success: [Linear::Search.method(:Noop)]}, **end_args)

  # PassFast
    end_pass_fast   = Activity::End.new(semantic: :pass_fast)
    @sequence = step(end_pass_fast, sequence: @sequence, magnetic_to: :pass_fast, id: "End.pass_fast", outputs: {pass_fast: end_pass_fast}, connections: {pass_fast: [Linear::Search.method(:Noop)]}, sequence_insert: [Linear::Insert.method(:Append), "End.success"])


    @sequence = step implementing.method(:a), sequence: @sequence, id: :a
    @sequence = fail implementing.method(:f), sequence: @sequence, id: :f, connections: {success: [Linear::Search.method(:ById), :d], failure: [Linear::Search.method(:ById), :c]}
    @sequence = step implementing.method(:b), sequence: @sequence, id: :b, outputs: default_binary_outputs.merge(pass_fast: Activity::Output("Special signal", :pass_fast)), connections: default_step_connections.merge(pass_fast: [Linear::Search.method(:Forward), :pass_fast])
    @sequence = fail implementing.method(:c), sequence: @sequence, id: :c
    @sequence = step implementing.method(:d), sequence: @sequence, id: :d
  end

  it "DSL to change {Sequence} and compile it to a {Process}" do
pp sequence
    process = Linear::Compiler.(sequence)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)
    puts cct
    cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.f>
#<Method: #<Module:0x>.f>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Special signal} => #<End/:pass_fast>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:failure>
}
  end

  it "supports :replace, :delete, :inherit" do
    _sequence = sequence

    _sequence = step implementing.method(:g), sequence: _sequence, id: :g, sequence_insert: [Linear::Insert.method(:Replace), :f]
    _sequence = step nil, sequence: _sequence, id: nil,                    sequence_insert: [Linear::Insert.method(:Delete), :d]
# pp _sequence
    process = Linear::Compiler.(_sequence)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)
    # puts cct
    cct.must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.g>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Special signal} => #<End/:pass_fast>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:pass_fast>

#<End/:failure>
}
  end

  it "simple linear approach where a {Sequence} is compiled into an Intermediate/Implementation" do
    seq = [
      [
        nil,
        implementing::Start,
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
        ],
        {id: "Start.default"},
      ],
      [
        :success, # MinusPole
        # [Search::Forward(:success), Search::ById(:a)]
        implementing.method(:a),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          ),
        ],
        {id: :a},
      ],
      [
        :success,
        implementing.method(:b),
        [
          Linear::Search::Forward(
            Activity::Output("B/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output("B/failure", :failure),
            :failure
          )
        ],
        {id: :b},
      ],
      [
        :failure,
        implementing.method(:c),
        [
          Linear::Search::Forward(
            Activity::Output(Right, :success),
            :failure
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
         )
        ],
        {id: :c},
      ],
      [
        :success,
        implementing.method(:d),
        [
          Linear::Search::Forward(
            Activity::Output("D/success", :success),
            :success
          ),
          Linear::Search::Forward(
            Activity::Output(Left, :failure),
            :failure
          )
        ],
        {id: :d},
      ],
      [
        :success,
        implementing::Success,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Success, :success)
          )
        ],
        {id: "End.success", stop_event: true},
      ],
      [
        :failure,
        implementing::Failure,
        [
          Linear::Search::Noop(
            Activity::Output(implementing::Failure, :failure)
          )
        ],
        {id: "End.failure", stop_event: true},
      ],
    ]

    process = Linear::Compiler.(seq)

    cct = Trailblazer::Developer::Render::Circuit.(process: process)

    cct.must_equal %{
#<Start/:default>
 {LinearTest::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {LinearTest::Right} => #<Method: #<Module:0x>.b>
 {LinearTest::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {LinearTest::Right} => #<End/:failure>
 {LinearTest::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {LinearTest::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

  end
end

# TODO: test when target can't be found
