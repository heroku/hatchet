require 'test_helper'

class LockTest < Minitest::Test
  def test_app_with_failure_can_be_locked_to_prior_commit
    Hatchet::GitApp.new("lock_fail").deploy do |app|
      assert app.deployed?
    end
  end

  def test_app_with_failure_can_be_locked_to_master
    puts `bundle exec hatchet lock`

    lock = YAML.load_file("hatchet.lock")
    name, branch = lock.select {|k,v| k.end_with?("lock_fail_master") }.first
    assert_equal "test/fixtures/repos/lock/lock_fail_master", name
    assert_equal "master", branch
  end
end
