require 'test_helper'

class HerokuApiTest < Minitest::Test

  def test_config_vars
    runner = Hatchet::Runner.new("no_lockfile").setup!
    expected = {}
    actual  = runner.get_config
    actual.delete("BUILDPACK_URL")
    assert_equal expected, actual

    runner.set_config("foo" => "bar")
    expected = {"foo" => "bar"}
    actual   = runner.get_config
    actual.delete("BUILDPACK_URL")
    assert_equal expected, actual
  ensure
    runner.teardown! if runner
  end
end
