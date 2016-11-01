require 'test_helper'

class AppTest < Test::Unit::TestCase
  def test_create_app_with_stack
    app = Hatchet::App.new("rails3_mri_193", stack: "cedar-14")
    app.create_app
    assert_equal 'cedar-14', app.heroku.get_app(app.name).body["stack"]
  end
end
