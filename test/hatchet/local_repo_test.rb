require 'test_helper'

class LocalRepoTest < Minitest::Test
  def test_in_directory_fork
    env_name = SecureRandom.hex
    ENV[env_name] = env_name

    Hatchet::App.new("default_ruby").in_directory_fork do
      ENV.delete(env_name)
      assert_nil ENV[env_name]
    end

    assert_equal env_name, ENV[env_name]
  end

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
