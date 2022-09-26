require 'rrrretry'

require 'json'
require 'stringio'
require 'fileutils'
require 'stringio'
require 'date'

module Hatchet
  APP_PREFIX = (ENV['HATCHET_APP_PREFIX'] || "hatchet-t-")
end

require 'hatchet/version'
require 'hatchet/reaper'
require 'hatchet/test_run'
require 'hatchet/app'
require 'hatchet/anvil_app'
require 'hatchet/git_app'
require 'hatchet/config'
require 'hatchet/api_rate_limit'
require 'hatchet/init_project'
require 'hatchet/heroku_run'

module Hatchet
  RETRIES = Integer(ENV['HATCHET_RETRIES']   || 1)
  Runner  = Hatchet::GitApp

  def self.git_branch
    # https://circleci.com/docs/variables
    return ENV['CIRCLE_BRANCH'] if ENV['CIRCLE_BRANCH']
    # https://docs.github.com/en/actions/learn-github-actions/environment-variables
    return ENV['GITHUB_REF_NAME'] if ENV['GITHUB_REF_NAME']
    # https://devcenter.heroku.com/articles/heroku-ci#immutable-environment-variables
    return ENV['HEROKU_TEST_RUN_BRANCH'] if ENV['HEROKU_TEST_RUN_BRANCH']
    # TRAVIS_BRANCH works fine unless the build is a pull-request. In that case, it will contain the target branch
    # not the actual pull-request branch! TRAVIS_PULL_REQUEST_BRANCH contains the correct branch but will be empty
    # for push builds. See: https://docs.travis-ci.com/user/environment-variables/
    return ENV['TRAVIS_PULL_REQUEST_BRANCH'] if ENV['TRAVIS_PULL_REQUEST_BRANCH'] && !ENV['TRAVIS_PULL_REQUEST_BRANCH'].empty?
    return ENV['TRAVIS_BRANCH'] if ENV['TRAVIS_BRANCH']

    out = `git rev-parse --abbrev-ref HEAD`.strip
    raise "Attempting to find current branch name. Error: Cannot describe git: #{out}" unless $?.success?
    out
  end

  if ENV["HATCHET_DEBUG_DEADLOCK"]
    Thread.new do
      loop do
        sleep ENV["HATCHET_DEBUG_DEADLOCK"].to_f # seconds
        Thread.list.each { |t| puts "=" * 80; puts t.backtrace }
      end
    end
  end
end

unless ::String.instance_methods.include?(:strip_heredoc)
  # We can get rid of this when all rubies can support <<~ syntax
  class ::String
    def strip_heredoc
      gsub(/^#{scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
    end
  end
end

unless ::String.instance_methods.include?(:match?)
  # We can get rid of this when all rubies can support String#match? method
  class ::String
    def match?(value)
      self =~ value
    end
  end
end

