require 'test_helper'

class AppTest < Minitest::Test
  def test_repos_checked_into_git
    app = Hatchet::App.new("test/different-folder-for-checked-in-repos/default_ruby")
    app.in_directory do
      assert_equal false, Dir.exist?(".git")
      app.setup!
      assert_equal true, Dir.exist?(".git")
    end
  ensure
    app.teardown! if app
  end
end
