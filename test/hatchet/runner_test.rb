require 'test_helper'

class HatchetRunnerTest < Test::Unit::TestCase

  def setup
    @default = ENV['HATCHET_DEPLOY_STRATEGY']
  end

  def teardown
    ENV['HATCHET_DEPLOY_STRATEGY'] = @default
    Hatchet.set_deploy_strategy!
  end

  def test_defaults
    assert_equal nil, ENV['HATCHET_DEPLOY_STRATEGY']
    assert_equal :git, Hatchet::DEPLOY_STRATEGY
    assert_equal Hatchet::GitApp, Hatchet::Runner
  end

  def test_change_deploy_strat
    ENV['HATCHET_DEPLOY_STRATEGY'] = "git"
    Hatchet.set_deploy_strategy!
    assert_equal :git, Hatchet::DEPLOY_STRATEGY
    assert_equal Hatchet::GitApp, Hatchet::Runner

    ENV['HATCHET_DEPLOY_STRATEGY'] = "anvil"
    Hatchet.set_deploy_strategy!
    assert_equal :anvil, Hatchet::DEPLOY_STRATEGY
    assert_equal Hatchet::AnvilApp, Hatchet::Runner
  end
end
