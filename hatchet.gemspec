# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hatchet/version'

Gem::Specification.new do |gem|
  gem.name          = "hatchet"
  gem.version       = Hatchet::VERSION
  gem.authors       = ["Richard Schneeman"]
  gem.email         = ["schneems@gmail.com"]
  gem.description   = %q{The Hatchet is a an integration testing library for developing Heroku buildpacks.}
  gem.summary       = %q{The Hatchet is a an integration testing library for developing Heroku buildpacks.}
  gem.homepage      = ""
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "heroku-api"
  gem.add_dependency "activesupport"
  gem.add_dependency "rake"
  gem.add_dependency "anvil-cli"
end
