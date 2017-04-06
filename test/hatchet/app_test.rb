require 'test_helper'

class AppTest < Minitest::Test
  def test_create_app_with_stack
    stack = "heroku-16"
    app = Hatchet::App.new("default_ruby", stack: stack)
    app.create_app
    assert_equal stack, app.platform_api.app.info(app.name)["build_stack"]["name"]
  end
end
