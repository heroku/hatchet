require 'heroku/api'
require 'anvil/engine'
require 'active_support/core_ext/object/blank'
require 'rrrretry'
require 'repl_runner'

require 'json'
require 'stringio'
require 'fileutils'
require 'stringio'


module Hatchet
  RETRIES   = Integer(ENV['HATCHET_RETRIES']   || 1)

  class App
  end

  def self.git_branch
    return ENV['TRAVIS_BRANCH'] if ENV['TRAVIS_BRANCH']
    out = `git describe --contains --all HEAD`.strip
    raise "Attempting to find current branch name. Error: Cannot describe git: #{out}" unless $?.success?
    out
  end

  def self.set_deploy_strategy!
    deploy_strat = (ENV['HATCHET_DEPLOY_STRATEGY'] || :anvil).to_sym
    case Hatchet::const_set("DEPLOY_STRATEGY", deploy_strat)
    when :anvil
      Hatchet.const_set("Runner", Hatchet::AnvilApp)
    when :git
      Hatchet.const_set("Runner", Hatchet::GitApp)
    else
      raise "unknown deploy strategy #{Hatchet::DEPLOY_STRATEGY}, expected 'anvil', 'git'"
    end
  end
end

require 'hatchet/version'
require 'hatchet/reaper'
require 'hatchet/app'
require 'hatchet/anvil_app'
require 'hatchet/git_app'
require 'hatchet/config'


Hatchet.set_deploy_strategy!
