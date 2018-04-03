require 'test_helper'

class LockTest < Minitest::Test
  def test_app_with_failure_can_be_locked_to_prior_commit
    Hatchet::GitApp.new("lock_fail").deploy do |app|
      assert app.deployed?
    end
  end
end
