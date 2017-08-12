require 'test_helper'

class CITest < Minitest::Test

  def test_ci_create_app_with_stack
    Hatchet::GitApp.new("rails5_ruby_schema_format").run_ci do |test_run|
      assert_match "Ruby buildpack tests completed successfully", test_run.output
      assert_equal :succeeded, test_run.status
    end
  end

  def test_error_with_bad_app
    error = assert_raise(Hatchet::FailedTestError) do
      Hatchet::GitApp.new("rails5_ci_fails_no_database").run_ci {}
    end

    assert_match "PG::ConnectionBad: could not connect to server" ,error.message

    Hatchet::GitApp.new("rails5_ci_fails_no_database", allow_failure: true).run_ci do |test_run|
      assert_equal :errored, test_run.status
    end
  end
end
