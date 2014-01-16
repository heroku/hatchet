require 'test_helper'

class HerokuApiTest < Test::Unit::TestCase

  def test_config_vars
    runner = Hatchet::Runner.new("no_lockfile").setup!
    expected = {}
    assert_equal expected, runner.get_config
    runner.set_config("foo" => "bar")
    expected = {"foo" => "bar"}
    assert_equal expected, runner.get_config
  ensure
    runner.teardown! if runner
  end
end
