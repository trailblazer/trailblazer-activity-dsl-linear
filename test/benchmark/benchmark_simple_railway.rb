# Run me in this directory using
#
#   bundle exec appraisal trb-2.1 ruby benchmark_simple_railway.rb

require "trailblazer/activity/dsl/linear"

module Create
  def model(ctx, params:, **kws)
    ctx[:spam] = false
    ctx[:model] = "Object #{params[:id]} / #{kws.inspect}"
  end

  # Add params[:slug],
  def my_model_input(ctx, params:, slug:, **)
    {
      params: params.merge(slug: slug)
    }
  end

  # In() => MoreModelInput
  class MoreModelInput
    def self.call(ctx, slug:, **)
      {
        more: slug
      }
    end
  end

  # Out() => [:model]
  def my_model_output(ctx, model:, **)
    {
      model: model
    }
  end
end

module Validate
  def run_checks(ctx, params:, model:, **)
    if params[:song]
      return true
    else
      ctx[:errors] = [model, :song]
      return false
    end
  end

  def title_length_ok?(ctx, params:, **)
    return false unless params[:song][:title]

    return true
  end
end

# step interface.
class Save
  def self.call(ctx, model:, **)
    ctx[:save] = model
  end
end

validate = Class.new(Trailblazer::Activity::Railway) do
  include Validate
  step :run_checks
  step :title_length_ok?
end

create = Class.new(Trailblazer::Activity::Railway) do
  include Create
  step :model,
    In() => :my_model_input,
    In() => Create::MoreModelInput,
    Out() => [:model]
  step Subprocess(validate)
  step Save
end

def call_me(create)
  signal, (ctx, _) =  Trailblazer::Activity::TaskWrap.invoke(create, [{params: {song: {title: "Uwe"}}, slug: "0x999", noise: true}, {}], )
end

signal, (ctx, _) = call_me(create)

puts "???@@@@@ #{ctx.keys.inspect}"
pp ctx

require "benchmark/ips"
Benchmark.ips do |x|
  x.report("procs") {
    signal, (ctx, _) = call_me(create)
  }

  x.compare!
end

