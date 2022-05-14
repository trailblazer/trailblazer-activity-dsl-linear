require "test_helper"

class DslTest < Minitest::Spec


  Imp = T.def_tasks(:a, :b, :c, :d, :f, :g)



  it "importing helpers and constants" do
    Trailblazer::Activity::DSL::Linear::Helper.module_eval do # FIXME: make this less global!
      def MyHelper()
        {task: "Task", id: "my_helper.task"}
      end
    end

    module MyMacros
      def self.MyHelper()
        {task: "Task 2", id: "my_helper.task"}
      end
    end

    Trailblazer::Activity::DSL::Linear::Helper::Constants::My = MyMacros


    state, _ = Activity::Path::DSL::State.build(**Activity::Path::DSL.OptionsForState())
    state.step state.MyHelper()

# FIXME: how are we gonna do this?
    # state.instance_exec do
    #   step My::MyHelper()
    # end

    sequence = state.to_h[:sequence]

    assert_process sequence, :success, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task\"
\"Task\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end
end
