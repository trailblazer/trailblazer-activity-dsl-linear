lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "trailblazer/activity/dsl/linear/version"


Gem::Specification.new do |spec|
  spec.name          = "trailblazer-activity-dsl-linear"
  spec.version       = Trailblazer::Version::Activity::DSL::Linear::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = %q(Simple DSL to compile Trailblazer activities.)
  spec.description   = %q(Simple DSL to compile Trailblazer activities with arbitrary wirings.)
  spec.homepage      = "http://trailblazer.to"
  spec.licenses      = ["MIT"]

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "trailblazer-activity"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "trailblazer-developer"

  spec.required_ruby_version = '>= 2.1.0'
end
