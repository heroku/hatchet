require 'test_helper'

class AllowFailureGitTest < Minitest::Test
  def test_allowed_failure
    Hatchet::GitApp.new("no_lockfile", allow_failure: true).deploy do |app|
      refute app.deployed?
      assert_match "Gemfile.lock required", app.output
    end
  end

  def test_failure_with_no_flag
    assert_raise(Hatchet::App::FailedDeploy) do
      Hatchet::GitApp.new("no_lockfile").deploy
    end
  end
end
