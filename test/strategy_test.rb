require "test_helper"

class StrategyTest < Minitest::Spec
  it "empty Strategy" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)
    assert_nil strategy.to_h[:sequence]

#     assert_equal CU.strip(CU.inspect(strategy.to_h[:sequence])), %(#<Trailblazer::Activity::DSL::Linear::Sequence:0x @sequence=[[\"Start.default\", #<struct Trailblazer::Activity::DSL::Linear::Sequence::Row magnetic_to=nil, task=#<Trailblazer::Activity::Start semantic=:default>, wirings=[], data=#{{:id=>"Start.default"}.inspect}, task_wrap=#{CU.strip(Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP.inspect)}>]]>)

#     assert_circuit strategy.to_h, %{
# #<Start/:default>
# }

#     assert_call strategy
  end

  let(:default_normalizer_extensions_in_fields) { {normalizer_extensions: Trailblazer::Activity::DSL::Linear::Strategy::INITIAL_NORMALIZER_EXTENSIONS} }

#@ State-relevant tests
  it "provides {:fields} in {@state} which is an (inherited) hash" do
    strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy)

    sub      = Class.new(strategy)
    sub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(representer: Module) }

    subsub   = Class.new(sub)
    subsub.instance_variable_get(:@state).update!(:fields) { |fields| fields.merge(policy: Object) }

    assert_equal strategy.to_h[:fields], default_normalizer_extensions_in_fields # only contains library defaults, no user fields, yet.
    assert_equal sub.to_h[:fields], default_normalizer_extensions_in_fields.merge(representer: Module)
    assert_equal subsub.to_h[:fields], default_normalizer_extensions_in_fields.merge(representer: Module, policy: Object)
  end

#@ Strategy API
  it "{Strategy#to_h} represents an interface for accessing internal data structures" do
    activity = Class.new(Activity::Path) do
      step :model
    end

    hsh = activity.to_h

    assert_equal hsh.keys.inspect, %{[:circuit, :outputs, :nodes, :config, :activity, :sequence, :fields]}
    assert_equal hsh[:activity].class, Trailblazer::Activity
    assert_equal hsh[:sequence].class, Trailblazer::Activity::Pipeline
    assert_equal hsh[:sequence].to_a.size, 3 # DISCUSS: private API.
    assert_equal hsh[:fields], default_normalizer_extensions_in_fields # FIXME: get the Pipeline vs. ary conflict sorted.
  end

#@ DSL tests
  it "importing helpers and constants" do
  #@ we can add methods to {Helper}. # TODO: document us!
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

  #@ we can add constants to {Helper::Constants}.
    Trailblazer::Activity::DSL::Linear::Helper::Constants::My = MyMacros

    strategy = Class.new(Trailblazer::Activity::Path) # DISCUSS: should this be just {Linear::Strategy}?
    strategy.instance_exec do
      step MyHelper()
    end


    assert_circuit strategy, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task\"
\"Task\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    strategy = Class.new(Trailblazer::Activity::Path)
    strategy.class_eval <<-EOS
      step My::MyHelper()
EOS

    assert_circuit strategy, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => \"Task 2\"
\"Task 2\"
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "{Strategy.invoke} runs activity using taskWrap" do
    activity = Class.new(Activity::Railway) do
      step :dont_run_me
      step :find_model, Out() => [:model]
      step :save

      include T.def_steps(:find_model, :save)
    end

    start_task = Activity::Introspect.Nodes(activity, id: :find_model).task
    ctx = {seq: []}
    #@ Positionals and kwargs are passed on:
    ctx, _, signal = activity.invoke(ctx, {}, start_task: start_task)

    assert_equal signal.to_h[:semantic], :success
    # The presence of {:model} here means taskWrap extensions have been run.
    assert_equal CU.inspect(ctx), %{{:seq=>[:find_model, :save], :model=>nil}}
  end


  it "allows {Introspect.Nodes()}" do
    activity = Class.new(Activity::Railway) do
      step :a
    end

    assert_equal Activity::Introspect.Nodes(activity, id: :a).id, :a
  end

  it "all strategies expose correct terminus data" do
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Path, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Railway, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::Railway, id: "End.failure").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:failure})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.success").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:success})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.failure").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:failure})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.fail_fast").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:fail_fast})
    assert_equal CU.inspect(Activity::Introspect.Nodes(Activity::FastTrack, id: "End.pass_fast").data.slice(:stop_event, :semantic)), %({:stop_event=>true, :semantic=>:pass_fast})
  end

  describe "#step to normalizer behavior" do
    activity = Class.new(Trailblazer::Activity::Path) do
      step :a, magnetic_to: :success
    end

    pp activity.to_h
  end

  # describe "Stragegy::Build" do
  describe "#compile_strategy!" do
    module MyPath
      def self.options_for_build(track_name:) # {track_name} is passed through {#compile_strategy!}.
        {
          layout_instructions: [
            [:step, id: "Start.default",   task: Trailblazer::Activity::Start.new(semantic: :default), magnetic_to: nil, after: nil],
            [:terminus, id: "End.#{track_name}", task: Trailblazer::Activity::End.new(semantic: track_name), magnetic_to: track_name, after: nil],
          ],

          normalizers: Trailblazer::Activity::Path::DSL::Normalizers,

          normalizer_options: {
            track_name: track_name,
# FIXME: needed in #wrap_task_with_step_interface
            step_interface_builder: ->(task) { task },
# FIXME: needed in #normalize_sequence_insert
            end_id: "End.#{track_name}",
          }
        }
      end
    end

    it "we can use {MyStrategy.options_for_build} to set up basic DSL behavior, and we can pass {user_options_for_strategy} to {#compile_strategy!}" do
      # NOTE: All we want to do here is compose a sequence and compile it to an activity.
      # And we're storing that and calling/invoking it via Strategy.call

      my_strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy) do
        compile_strategy!(MyPath, {track_name: :winning}) # sets @sequence.
      end

      activity = Class.new(my_strategy) do
        step :a, magnetic_to: :success # never reached, not connected.
        step T.def_tasks(:b).method(:b)#, magnetic_to: :winning
      end

      assert_call activity, seq: "[:b]", terminus: :winning
    end

    def my_normalizer(ctx, flow_options, _, task:, id:, **)
      ctx = ctx.merge(
        adds: [
          [
            Trailblazer::Activity::DSL::Linear::Sequence.Row(
              task: task,
              magnetic_to: nil,
              wirings: [],
              data: {id: id, stop_event: true, semantic: :bla},
              task_wrap: nil
            ),
            id: id,
            prepend: nil,
          ]
        ],
      )
      return ctx, flow_options
    end

    it "we can override normalizers and layout_instructions, for example, when building small, fast Railways in Representable or Reform" do
      my_normalizer = method(:my_normalizer)

      my_strategy = Class.new(Trailblazer::Activity::DSL::Linear::Strategy) do
        # This normalizer is basically one step that returns {:adds}. Note that each step is *prepended* to sequence,
        # making {my_all_in_one_step} the first (and also last).

        # my_strategy_options = MyPath.options_for_build(track_name: :winning)
        my_strategy_options = {
          layout_instructions: [
            # no terminus, we don't need it, thanks to our magic normalizer, see below.
            [:step, id: "Start.default", task: Trailblazer::Activity::Start.new(semantic: :default), magnetic_to: nil, after: nil, sequence: []],
          ],
          normalizers: Trailblazer::Activity::DSL::Linear::Normalizer::Normalizers.new(
            step: {
              normalize_for_macro: Trailblazer::Activity::DSL::Linear::Normalizer.method(:merge_user_options),
              normalize_ctx: Trailblazer::Activity::DSL::Linear::Normalizer.method(:normalize_context),
              my_normalizer_step: my_normalizer,
              compile_sequence: Trailblazer::Activity::DSL::Linear::Normalizer.method(:apply_adds),
            }
          ),
          normalizer_options: {}
        }

        compile_strategy!(MyPath, {}, my_strategy_options) # sets @sequence.
      end

      activity = Class.new(my_strategy) do
        # This is a start, business and stop task.
        def self.my_all_in_one_step(ctx, flow_options, _)
          ctx[:seq] << :my_all_in_one_step
          return ctx, flow_options, {semantic: :winning}
        end

        step task: method(:my_all_in_one_step), id: :my_id
      end

      assert_call activity, seq: "[:my_all_in_one_step]", terminus: :winning
    end

    it "we can also use Strategy.Build() to override normalizers etc" do
      my_normalizer = method(:my_normalizer)

      my_strategy_options = {
          layout_instructions: [
            # no terminus, we don't need it, thanks to our magic normalizer, see below.
            [:step, id: "Start.default", task: Trailblazer::Activity::Start.new(semantic: :default), magnetic_to: nil, after: nil],
          ],
          normalizers: Trailblazer::Activity::DSL::Linear::Normalizer::Normalizers.new(
            step: {
              normalize_for_macro: Trailblazer::Activity::DSL::Linear::Normalizer.method(:merge_user_options),
              normalize_ctx: Trailblazer::Activity::DSL::Linear::Normalizer.method(:normalize_context),
              my_normalizer_step: my_normalizer,
              compile_sequence: Trailblazer::Activity::DSL::Linear::Normalizer.method(:apply_adds),
            }
          ),
          normalizer_options: {}
        }

      activity = Trailblazer::Activity::DSL::Linear::Strategy::DSL.Build(Trailblazer::Activity::DSL::Linear::Strategy, {}, my_strategy_options) do
        def self.my_all_in_one_step(ctx, flow_options, _)
          ctx[:seq] << :my_all_in_one_step
          return ctx, flow_options, {semantic: :winning}
        end

        step task: method(:my_all_in_one_step), id: :my_id
      end

      assert_call activity, seq: "[:my_all_in_one_step]", terminus: :winning
    end
  end

  # it "you can override #step and #terminus and that won't affect the basic layout" do
  #   activity = Class.new(Trailblazer::Activity::Strategy) do

  #   end
  # end

  it "all termini should be at the end of sequence, even if they were created somewhere before" do
    # raise ""
    activity = Class.new(Trailblazer::Activity::Path) do
      step :a
      terminus :failure
      step :b, Output(:success) => End(:winning)
      step :c
    end

    assert_circuit activity, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:winning>
<*c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>

#<End/:winning>
)

   # task_wrap=
   #  #<Trailblazer::Activity::Pipeline:0x000074f80764c700
   #   @sequence=
   #    [["task_wrap.call_task", #<Method: Trailblazer::Activity::TaskWrap.call_task(wrap_ctx, flow_options, _) /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/task_wrap/call_task.rb:6>],
   #     ["task_wrap.call_task", #<Method: Trailblazer::Activity::TaskWrap.call_task(wrap_ctx, flow_options, _) /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/task_wrap/call_task.rb:6>],
   #     ["task_wrap.call_task", #<Method: Trailblazer::Activity::TaskWrap.call_task(wrap_ctx, flow_options, _) /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/task_wrap/call_task.rb:6>],
   #     ["task_wrap.call_task", #<Method: Trailblazer::Activity::TaskWrap.call_task(wrap_ctx, flow_options, _) /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/task_wrap/call_task.rb:6>]]>>,
    assert_equal activity.to_h[:config][:wrap_static].values.last.to_a.size, 1
  end
end
