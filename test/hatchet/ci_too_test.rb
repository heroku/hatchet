require 'test_helper'

# Split out to be faster
class CITestToo < Minitest::Test
  def test_ci_create_app_with_stack
    Hatchet::GitApp.new("rails5_ruby_schema_format").run_ci do |test_run|
      assert_match "Ruby buildpack tests completed successfully", test_run.output
      assert_equal :succeeded, test_run.status
    end
  end
end
