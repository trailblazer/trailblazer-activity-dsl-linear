require "test_helper"
require "benchmark/ips"

class VariableMappingRuntimeTest < Minitest::Spec
  let(:vm) { Trailblazer::Activity::DSL::Linear::VariableMapping }

  it "what" do
    range = 1..30

    activity_with_pipelines = Class.new(Trailblazer::Activity::Railway) do
      range.each do |i|
        step i.to_s.to_sym, In() => [:model, :record, :params, :type, :action, :seq], Out() => [:model, :id, :seq]
      end

      include T.def_steps(*range.collect { |i| i.to_s.to_sym })

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
          Out(filters_builder: vm::DSL::Tuple::Left::Out::Builder) => [:model, :id, :seq]
      end

      include T.def_steps(*range.collect { |i| i.to_s.to_sym })
    end

    json_chunk = {
      a: {b: {c: 1}},
      b: 19999,
      c: {a: {b: {c: 1}},}
    }
    require "json"
    json_chunk = JSON.dump(json_chunk)

    pp Trailblazer::Activity::TaskWrap.invoke(activity_with_pipelines, [{seq: [], record: json_chunk, action: :edit, bla: 1}, {}])
    pp Trailblazer::Activity::TaskWrap.invoke(activity_with_activities, [{seq: [], record: json_chunk, action: :edit, bla: 1}, {}])
# raise
    Benchmark.ips do |x|
      x.report("object-based") {
        Trailblazer::Activity::TaskWrap.invoke(activity_with_pipelines, [{seq: [], record: json_chunk, action: :edit, bla: 1}, {}])
      }

      x.report("activity-based") do
        Trailblazer::Activity::TaskWrap.invoke(activity_with_activities, [{seq: [], record: json_chunk, action: :edit, bla: 1}, {}])
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


=end
