require "test_helper"
require "benchmark/ips"

class VariableMappingRuntimeTest < Minitest::Spec
  let(:vm) { Trailblazer::Activity::DSL::Linear::VariableMapping }

  it "what" do
    range = 1..30

    activity_with_pipelines = Class.new(Trailblazer::Activity::Railway) do
      range.each do |i|
        step i.to_s.to_sym, In() => [:model, :record, :params, :type, :action, :seq], Out() => [:model, :id, :seq],
        Out() => :my_output
      end

      include T.def_steps(*range.collect { |i| i.to_s.to_sym })

      def my_output(ctx, action:, **)
        {todo: action}
      end
      # step :parse, In() => [:model, :record, :params, :type, :action, :seq], Out() => [:model, :id, :seq]

      # def parse(ctx, record:, **)
      #   JSON.parse(record)
      # end
    end

    vm = vm()

    activity_with_activities = Class.new(Trailblazer::Activity::Railway) do
      range.each do |i|
        step i.to_s.to_sym,
          In(filters_builder: vm::DSL::Tuple::Left::In::Builder) => [:model, :record, :params, :type, :action, :seq],
          Out(filters_builder: vm::DSL::Tuple::Left::Out::Builder) => [:model, :id, :seq],
          input_class: vm::Pipe::Input_new, output_class: vm::Pipe::Output_new,
          Out(filters_builder: vm::DSL::Tuple::Left::Out::Builder) => :my_output
      end

      include T.def_steps(*range.collect { |i| i.to_s.to_sym })

      def my_output(ctx, action:, **)
        {todo: action}
      end
    end

    json_chunk = {
      a: {b: {c: 1}},
      b: 19999,
      c: {a: {b: {c: 1}},}
    }
    require "json"
    json_chunk = JSON.dump(json_chunk)
puts "testsssssssssssssssss"
    pp Trailblazer::Activity::TaskWrap.invoke(activity_with_pipelines, {seq: [], record: json_chunk, action: :edit, bla: 1}, {})
    pp Trailblazer::Activity::TaskWrap.invoke(activity_with_activities, {seq: [], record: json_chunk, action: :edit, bla: 1}, {})
# raise
    Benchmark.ips do |x|
      x.report("object-based") {
        Trailblazer::Activity::TaskWrap.invoke(activity_with_pipelines, {seq: [], record: json_chunk, action: :edit, bla: 1}, {})
      }

      x.report("activity-based") do
        Trailblazer::Activity::TaskWrap.invoke(activity_with_activities, {seq: [], record: json_chunk, action: :edit, bla: 1}, {})
      end

      x.compare!
    end
  end
end



=begin

1. 30 steps, each 5 In, 3 Out.
   FilterStep is called using normal Activity#call, no optimizations.

Comparison:
        object-based:     1393.9 i/s
      activity-based:      184.1 i/s - 7.57x  (± 0.00) slower



2. skip start. run circuit, only.

Comparison:
        object-based:     1507.5 i/s
      activity-based:      213.7 i/s - 7.06x  (± 0.00) slower

3. skip start and end. circuit only. runner that does exec_context.send(task_name, ctx, **ctx.to_h)
   no wrapping of task in circuit


Comparison:
    object-based:     1609.5 i/s
  activity-based:      470.0 i/s - 3.42x  (± 0.00) slower

  Code:
   _signal, (ctx, _) =  @circuit.([wrap_ctx.merge(@options), {}], exec_context: @filter_activity.new, runner: MyRunner)

   Trailblazer::Activity::DSL::Linear::Normalizer.extend!(self, :step, :pass) do |normalizer|
    _normalizer = Trailblazer::Activity::Adds.(
      normalizer,
      [nil, id: "activity.macro_options_with_symbol_task", delete: "activity.macro_options_with_symbol_task"],
      [nil, id: "activity.wrap_task_with_step_interface", delete: "activity.wrap_task_with_step_interface"],
    )
    pp _normalizer
  end

  MyRunner = ->(task_name, (ctx, flow_options), exec_context:, **) {
    new_ctx, _ = exec_context.send(task_name, ctx, **ctx.to_h)
    return Trailblazer::Activity::Right, [ctx, flow_options]
  }

4. Making Runner a class with {def self.call}

Comparison:
        object-based:     1503.6 i/s
      activity-based:      466.3 i/s - 3.22x  (± 0.00) slower

in ruby 3.4.1 2.80x slower. the above is Ruby 3.3.6.

5. class methods in MergeVariables, so we don't need exec_context: @filters_activity{.new}

Comparison:
        object-based:     1580.3 i/s
      activity-based:      582.0 i/s - 2.72x  (± 0.00) slower

6. using class instance variables instead of passing those through the ctx MAKES it slower! 3 -> 4x slower.
  this is in Ruby 3.3.6, in Ruby 3.4.1 the @filter approach is 2.8 => 2.7 improvement.
  we also save a merge in FilterStep.call

  _signal, (ctx, _) =  @circuit.([wrap_ctx.merge(@options), {}])
  # this is slower!
  _signal, (ctx, _) =  @circuit.([wrap_ctx, {}], exec_context: @filter_activity, runner: MyRunner)

  # we don't pass :filter kwarg here.
  def self.call_filter(ctx, args_for_filter:, **)
    variable, _ = @filter.(args_for_filter[0], **args_for_filter[1]) # circuit-step interface

    ctx[:value] = variable
  end


7. benchmarking with the "new" pipe
  activity_with_activities = Class.new(Trailblazer::Activity::Railway) do
      range.each do |i|
        step i.to_s.to_sym,
          In(filters_builder: vm::DSL::Tuple::Left::In::Builder) => [:model, :record, :params, :type, :action, :seq],
          Out(filters_builder: vm::DSL::Tuple::Left::Out::Builder) => [:model, :id, :seq],
          input_class: vm::Pipe::Input_new, output_class: vm::Pipe::Output_new
      end


8. decompose vs. manual

# (original_ctx, original_flow_options), original_circuit_options = original_args
              args = original_args[0]
              original_ctx, original_flow_options, original_circuit_options = args[0], args[1], original_args[1]

manual is .02 faster, can be ignored.

9. @pipe => @sequence

  @sequence = seq.collect { |_, config| config }
  @sequence.each do |filter_circuit, call_options|

from 2.71 to 2.68, it's also simply less runtime noise.


10. using positional circuit interface

Comparison:
        object-based:     1628.2 i/s
      activity-based:      652.7 i/s - 2.49x  (± 0.00) slower


11. concept of "atomic tasks" which have their own Runner and are
    called task.(ctx, **ctx.to_h). the ctx includes the potential :exec_context


Comparison:
        object-based:     1353.4 i/s
      activity-based:      541.7 i/s - 2.50x  (± 0.00) slower


12. DECISION: how much does the special "MyRunner" pass on to the tasks. we could always
              pass flow_options and circuit_options the way it was done before, and then
              the filter, or its wrap (like circuit step) would "filter out" what's needed
              however, the Runner that is doing kwargs directly is faster. TODO: benchmark how fast :D

              the runner is doing the TaskAdapter's job.

13. passing circuit_options along in the sequence invocation
  @sequence.each do |filter_circuit, call_options|
    signal, ctx_for_pipe, flow_options = filter_circuit.(ctx_for_pipe, flow_options, **circuit_options, **call_options)
    # vs.
    signal, ctx_for_pipe, flow_options = filter_circuit.(ctx_for_pipe, flow_options, **call_options)

    ==> the latter is 0.11x slower

  The discussion here is, do we want to lose flow_options and the "real" circuit_options once we're invoking a single "FilterStep" (e.g. In[:model])?
  what if, at some point in the future, we're deciding that a user can use an activity to compute an In() value, and that it should be traceable?
  we'd have to entirely change the Input pipeline implementation, and start over with fucking benchmarking.
=end


=begin

#<Pipe::Input
  we need this to build the aggregate at runtime, and to set the input ctx after the input pipe has been run.

pipe.call:

[
  #<FilterStep.call
  here, we merge the specific @options into {wrap_ctx}.
    this we could probably avoid by setting instance variables on Activity?

]




=end


=begin
in {activity} gem, playing with different "next step" logic.

         @termini     = termini
         @name        = name
         @start_task  = start_task
+
+        # @object_id_map = map.collect { |task, connections| [task.object_id, connections] }.to_h
       end

       # @param args [Array] all arguments to be passed to the task's `call`
@@ -50,6 +52,7 @@ module Trailblazer
           return [last_signal, args] if @termini.include?(task)

           if (next_task = next_for(task, last_signal))
+          # if (next_task = @tuple_to_target[[task, last_signal]]) # (7.) dis-improvement: from 6.55 to 7.5 slower with tuple-based key
             task = next_task
           else
             raise IllegalSignalError.new(
@@ -75,6 +78,7 @@ module Trailblazer

       def next_for(last_task, signal)
         outputs = @map[last_task]
+        # outputs = @object_id_map[last_task.object_id]
         outputs[signal]
       end
=end
