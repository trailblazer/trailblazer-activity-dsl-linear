require "test_helper"
# require "benchmark/ips"
require "stackprof"

Implementing = T.def_tasks(:b, :e, :B, :C, :f, :g, :h, :i, :j)
nested_activity = nil

# StackProf.run(mode: :cpu, out: 'stackprof-cpu-myapp.dump') do
StackProf.run(mode: :object, out: 'stackprof-cpu-myapp.dump') do

  flat_activity =
    Class.new(Trailblazer::Activity::FastTrack) do
      step task: Implementing.method(:B), id: :B
      step task: Implementing.method(:C), id: :C
    end

  nested_activity =
    Class.new(Trailblazer::Activity::FastTrack) do
      step task: Implementing.method(:b),
        id: :B,
        more: true,
        DataVariable() => :more
      step Subprocess(flat_activity), id: :D
      step task: Implementing.method(:e), id: :E
      step task: Implementing.method(:f)#, id: :E
      step task: Implementing.method(:g)#, id: :E
      step task: Implementing.method(:h)#, id: :E
      step task: Implementing.method(:i)#, id: :E
      step task: Implementing.method(:j)#, id: :E
    end
  #...
end


# StackProf.run(mode: :cpu, out: 'stackprof-cpu-myapp.dump') do
StackProf.run(mode: :object, out: 'stackprof-object-runtime.dump', raw: true) do

signal, (ctx, _) = nested_activity.invoke([{seq: []}, {}])
# puts ctx.inspect

end
