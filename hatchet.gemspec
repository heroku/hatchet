lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hatchet/version'

Gem::Specification.new do |gem|
  gem.name          = "heroku_hatchet"
  gem.version       = Hatchet::VERSION
  gem.authors       = ["Richard Schneeman"]
  gem.email         = ["richard.schneeman+rubygems@gmail.com"]
  gem.summary       = %q{Hatchet is an integration testing library for developing Heroku buildpacks.}
  gem.homepage      = "https://github.com/heroku/hatchet"
  gem.license       = "MIT"
  gem.metadata      = {
    "changelog_uri" => "https://github.com/heroku/hatchet/blob/main/CHANGELOG.md",
    "source_code_uri" => "https://github.com/heroku/hatchet",
  }

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]
  gem.required_ruby_version = '>= 3.3.0'

  gem.add_dependency "platform-api",  "~> 3"
  gem.add_dependency "rrrretry",      "~> 1"
  gem.add_dependency "excon",         "< 2"
  gem.add_dependency "parallel",      ">= 1.10", "< 3"
  gem.add_dependency "thor",          "~> 1"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake",           ">= 10"
  gem.add_development_dependency "parallel_split_test"
  gem.add_development_dependency "rspec-retry"
end
