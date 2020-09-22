$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'hatchet'
require 'rspec/retry'
require "bundler/setup"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"
  config.verbose_retry       = true # show retry status in spec process
  config.default_retry_count = 2 if ENV['IS_RUNNING_ON_CI'] # retry all tests that fail again

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

ENV['HATCHET_BUILDPACK_BASE'] = "https://github.com/heroku/heroku-buildpack-ruby.git"
ENV['HATCHET_BUILDPACK_BRANCH'] = "main"

require 'parallel_tests/test/runtime_logger' if ENV['RECORD_RUNTIME']

def run!(cmd)
  out = `#{cmd}`
  raise "Error running #{cmd}, output: #{out}" unless $?.success?
  out
end
