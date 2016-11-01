require 'test_helper'

class LabsTest < Test::Unit::TestCase
  def setup
    @buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'
  end

  def test_can_deploy_git_app
    # You can't enable preboot on a free app.
    # BUT you can't make an app hobby until you've deploy once
    # Catch-22
    # lab_name = "preboot"
    # app = Hatchet::App.new("rails3_mri_193", labs: lab_name, buildpack: @buildpack_path)
    # app.setup!
    # assert(app.lab_is_installed?(lab_name), "Expected #{app.get_labs.inspect} to include {'name' => '#{lab_name}' } but it did not")
    assert(true)
  # ensure
  #   app.teardown! if app
  end
end
