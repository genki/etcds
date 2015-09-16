# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'etcds/version'

Gem::Specification.new do |spec|
  spec.name          = "etcds"
  spec.version       = Etcds::VERSION
  spec.authors       = ["Genki Takiuchi"]
  spec.email         = ["genki@s21g.com"]

  spec.summary       = %q{etcd cluster manager}
  spec.homepage      = "https://github.com/genki/etcds"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
