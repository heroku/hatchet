require 'test_helper'

# Split out to be faster
class CITestToo < Minitest::Test
  def test_ci_create_app_with_stack
    app = Hatchet::GitApp.new("rails5_ruby_schema_format")
    app.run_ci do |test_run|
      assert_match "Ruby buildpack tests completed successfully", test_run.output
      assert_equal :succeeded, test_run.status
      refute_nil app.pipeline_id

      api_rate_limit = app.api_rate_limit.call
      couplings = api_rate_limit.pipeline_coupling.list_by_pipeline(app.pipeline_id)
      coupled_app = api_rate_limit.app.info(couplings.first["app"]["id"])
      assert_equal app.name, coupled_app["name"]
    end
    assert_nil app.pipeline_id
  end
end
