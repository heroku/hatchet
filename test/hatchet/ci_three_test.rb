require 'test_helper'

class CIThreeTest < Minitest::Test
  def test_error_with_bad_app
    Hatchet::GitApp.new("rails5_ci_fails_no_database", allow_failure: true).run_ci do |test_run|
      assert_equal :errored, test_run.status
    end
  end
end
