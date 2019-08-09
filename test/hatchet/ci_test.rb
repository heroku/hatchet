require 'test_helper'

class CITest < Minitest::Test
  def test_error_with_bad_app
    error = assert_raise(Hatchet::FailedTestError) do
      Hatchet::GitApp.new("rails5_ci_fails_no_database").run_ci {}
    end

    assert_match "PG::ConnectionBad: could not connect to server", error.message
  end
end
