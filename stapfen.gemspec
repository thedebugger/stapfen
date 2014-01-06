# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stapfen/version'

Gem::Specification.new do |gem|
  gem.name          = "stapfen"
  gem.version       = Stapfen::VERSION
  gem.authors       = ["R. Tyler Croy"]
  gem.email         = ["rtyler.croy@lookout.com"]
  gem.description   = "A simple gem for writing good basic STOMP workers"
  gem.summary       = "A simple gem for writing good basic STOMP workers"
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency("stomp", '>= 1.2.14')
  gem.add_dependency("jruby-jms") if RUBY_PLATFORM.to_s == "java"

  gem.add_development_dependency("rake")
  gem.add_development_dependency("rspec", "~> 2.11")
  gem.add_development_dependency("pry")
  gem.add_development_dependency("debugger") if RUBY_PLATFORM.to_s != "java"
  gem.add_development_dependency("debugger-pry") if RUBY_PLATFORM.to_s != "java"
end
