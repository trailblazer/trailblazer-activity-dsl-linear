require "test_helper"
require "benchmark/ips"

class FGdfgsdVariableMappingRuntimeTest < Minitest::Spec
  it "what" do

    class A
      def self.call((ctx, _), **o)
        ctx[:a] = "a"
      end
    end

    class B
      def self.call(ctx, _, **)
        ctx[:a] = "a"
      end
    end

    Benchmark.ips do |x|
      x.report("traditional, composed signature") {
        A.call([{}, {}], runner: Object)
      }

      x.report("positional") do
        B.call({}, {}, runner: Object)
      end

      x.compare!
    end
  end
end

# Comparison:
#           positional:  4148105.9 i/s
# traditional, composed signature:  3598373.4 i/s - 1.15x  (± 0.00) slower


class SignatureBenchmark < Minitest::Spec
  class Bla
    def self.mixed(ctx, flow_options, **circuit_options)
      ctx[:seq] << 1
    end

    def self.positional(ctx, flow_options, circuit_options)
      ctx[:seq] << 1
    end

    def self.positional_wildcard(ctx, *)
      ctx[:seq] << 1
    end

    # as oppossed to the "mixed" signature, we always have the **ctx keywords without any additional work.
    # this is, in Ruby 3.4.1, 1.5x slower if you actually access kwargs.
    # if you don't use kwargs and simply ignore them using **) (see #positional_wildcard_kwargs_wildcard),
    # this is only 1.24x slower!
    # if not passing a **ctx, this is 1.21x slower.
    def self.positional_wildcard_kwargs(ctx, *, seq:, **)
      seq << 1
    end

    def self.positional_wildcard_kwargs_wildcard(ctx, *, **)
      ctx[:seq] << 1
    end
  end

  it "comparing different signature concepts" do
    Benchmark.ips do |x|
      x.report("mixed") {
        Bla.mixed({seq: []}, {}, runner: Object)
      }

      x.report("positional") do
        Bla.positional({seq: []}, {}, {runner: Object})
      end

      x.report("positional_wildcard") do
        Bla.positional_wildcard({seq: []}, {}, {runner: Object})
      end

      x.report("positional_wildcard kwargs") do
        Bla.positional_wildcard_kwargs(ctx={seq: []}, {}, {runner: Object}, **ctx)
      end

      x.report("positional two wildcards") do
        Bla.positional_wildcard_kwargs_wildcard(ctx={seq: []}, {}, {runner: Object}, **ctx)
      end

      x.report("positional two wildcards, omitting **ctx") do
        Bla.positional_wildcard_kwargs_wildcard(ctx={seq: []}, {}, {runner: Object})
      end

      x.compare!

#       Comparison:
#           positional:        3208137.1 i/s
#                mixed:        2798721.9 i/s - 1.15x  (± 0.00) slower
#  positional_wildcard:        2684332.2 i/s - 1.20x  (± 0.00) slower
# positional_wildcard kwargs:  2141092.9 i/s - 1.50x  (± 0.00) slower

    end
  end
end
