$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'hatchet'

require 'bundler'
Bundler.require

# require 'test/unit'

require 'minitest/autorun'
require "mocha/minitest"

require 'minitest/retry'
Minitest::Retry.use!

def assert_raise(*args, &block)
  assert_raises(*args, &block)
end


ENV['HATCHET_BUILDPACK_BRANCH'] = "master"

require 'parallel_tests/test/runtime_logger' if ENV['RECORD_RUNTIME']

def run!(cmd)
  out = `#{cmd}`
  raise "Error running #{cmd}, output: #{out}" unless $?.success?
  out
end
