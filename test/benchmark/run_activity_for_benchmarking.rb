require "trailblazer-activity-dsl-linear"
require "trailblazer/core/utils"
require "trailblazer/core/utils/def_steps"
require "benchmark/ips"

range = 1..30

activity = Class.new(Trailblazer::Activity::Railway) do
  range.each do |i|
    step i.to_s.to_sym,#, In() => [:model, :record, :params, :type, :action, :seq],
    Out() => [:model, :id, :seq],
    In() => [:seq, :action],
    Out() => :my_output
  end

  include Trailblazer::Core::Utils::DefSteps.def_steps(*range.collect { |i| i.to_s.to_sym })

  def my_output(ctx, action:, **)
    {todo: action}
  end
  # step :parse, In() => [:model, :record, :params, :type, :action, :seq], Out() => [:model, :id, :seq]

  # def parse(ctx, record:, **)
  #   JSON.parse(record)
  # end
end

json_chunk = {
      a: {b: {c: 1}},
      b: 19999,
      c: {a: {b: {c: 1}},}
    }
require "json"
json_chunk = JSON.dump(json_chunk)

Benchmark.ips do |x|
  x.report("@TRB") {
    if ENV["NEW_SIGNATURE"]
      Trailblazer::Activity::TaskWrap.invoke(activity, {seq: [], record: json_chunk, action: :edit, bla: 1}, {}, {})
    else
      Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: [], record: json_chunk, action: :edit, bla: 1}, {}], **{})
    end
  }

  # x.report("activity-based") do
  #   Trailblazer::Activity::TaskWrap.invoke(activity_with_activities, {seq: [], record: json_chunk, action: :edit, bla: 1}, {})
  # end

  x.compare!
end
