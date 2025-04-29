require "test_helper"

def a(x=1)
end

# This is a unit test that helps understanding how {Compiler} and {Sequence} work.
class CompilerTest < Minitest::Spec
  R = Trailblazer::Activity::Right
  L = Trailblazer::Activity::Left
  Lin = Trailblazer::Activity::DSL::Linear
  Act = Trailblazer::Activity

  it "simple linear approach where a {Sequence} is compiled into an {Activity}" do
    sequence = Trailblazer::Activity::DSL::Linear::Sequence
    default_task_wrap = Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP

    seq = [
      sequence.Row(
        magnetic_to:  nil,
        task:         implementing::Start,
        wirings:
          [
            Lin::Sequence::Search::Forward(
              Act::Output(R, :success),
              :success
            ),
          ],
        task_wrap: default_task_wrap,
        data: {id: "Start.default"},
      ),
      sequence.Row(
        magnetic_to: :success, # MinusPole
        # [Search::Forward(:success), Search::ById(:a)]
        task: implementing.method(:a),
        wirings:
          [
            Lin::Sequence::Search::Forward(
              Act::Output(R, :success),
              :success
            ),
            Lin::Sequence::Search::Forward(
              Act::Output(L, :failure),
              :failure
            ),
          ],
        task_wrap: default_task_wrap,
        data: {id: :a},
      ),
      sequence.Row(
        magnetic_to: :success,
        task: implementing.method(:b),
        wirings:
          [
            Lin::Sequence::Search::Forward(
              Act::Output("B/success", :success),
              :success
            ),
            Lin::Sequence::Search::Forward(
              Act::Output("B/failure", :failure),
              :failure
            )
          ],
        task_wrap: default_task_wrap,
        data: {id: :b},
      ),
      sequence.Row(
        magnetic_to: :failure,
        task: implementing.method(:c),
        wirings:
          [
            Lin::Sequence::Search::Forward(
              Act::Output(R, :success),
              :failure
            ),
            Lin::Sequence::Search::Forward(
              Act::Output(L, :failure),
              :failure
           )
          ],
        task_wrap: default_task_wrap,
        data: {id: :c},
      ),
      sequence.Row(
        magnetic_to: :success,
        task: implementing.method(:d),
        wirings:
          [
            Lin::Sequence::Search::Forward(
              Act::Output("D/success", :success),
              :success
            ),
            Lin::Sequence::Search::Forward(
              Act::Output(L, :failure),
              :failure
            )
          ],
        task_wrap: default_task_wrap,
        data: {id: :d},
      ),
      sequence.Row(
        magnetic_to: :success,
        task: implementing::Success,
        wirings: [],
        task_wrap: default_task_wrap,
        data: {id: "End.success", stop_event: true, semantic: :success},
      ),
      sequence.Row(
        magnetic_to: :failure,
        task: implementing::Failure,
        wirings: [],
        task_wrap: default_task_wrap,
        data: {id: "End.failure", stop_event: true, semantic: :failure},
      ),
    ]

    schema = Lin::Sequence::Compiler.(seq)

    cct = Cct(schema)

    _(cct).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {B/success} => #<Method: #<Module:0x>.d>
 {B/failure} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<Method: #<Module:0x>.d>
 {D/success} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}

  end
end
