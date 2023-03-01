require "test_helper"

#:intermediate
  def a(x=1)
  end
#:intermediate end

class CompilerTest < Minitest::Spec
  R = Trailblazer::Activity::Right
  L = Trailblazer::Activity::Left
  Lin = Trailblazer::Activity::DSL::Linear
  Act = Trailblazer::Activity

  it "simple linear approach where a {Sequence} is compiled into an Intermediate/Implementation" do
    seq = [
      [
        nil,
        implementing::Start,
        [
          Lin::Sequence::Search::Forward(
            Act::Output(R, :success),
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
          Lin::Sequence::Search::Forward(
            Act::Output(R, :success),
            :success
          ),
          Lin::Sequence::Search::Forward(
            Act::Output(L, :failure),
            :failure
          ),
        ],
        {id: :a},
      ],
      [
        :success,
        implementing.method(:b),
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
        {id: :b},
      ],
      [
        :failure,
        implementing.method(:c),
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
        {id: :c},
      ],
      [
        :success,
        implementing.method(:d),
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
        {id: :d},
      ],
      [
        :success,
        implementing::Success,
        [],
        {id: "End.success", stop_event: true, semantic: :success},
      ],
      [
        :failure,
        implementing::Failure,
        [],
        {id: "End.failure", stop_event: true, semantic: :failure},
      ],
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
