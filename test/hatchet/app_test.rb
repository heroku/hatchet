require 'test_helper'

class AppTest < Minitest::Test
  def test_create_app_with_stack
    stack = "heroku-16"
    app = Hatchet::App.new("default_ruby", stack: stack)
    app.create_app
    assert_equal stack, app.platform_api.app.info(app.name)["build_stack"]["name"]
  end

  def test_before_deploy
    @called = false
    @dir    = false
    before_deploy = Proc.new do
      @called = true
      @dir    = Dir.pwd
    end

    app = Hatchet::App.new("default_ruby", before_deploy: before_deploy)
    def app.push_with_retry!; end # Don't actually deploy

    app.deploy do
      assert_equal true,    @called

      assert_equal Dir.pwd, @dir
    end

    refute_equal Dir.pwd, @dir
  end

  def test_auto_commits_code
    string = "foo#{SecureRandom.hex}"
    before_deploy = Proc.new do |app|
      assert_equal false, app.send(:needs_commit?)
      `echo "#{string}" > Gemfile`
      assert_equal true, app.send(:needs_commit?)
    end

    app = Hatchet::App.new("default_ruby", before_deploy: before_deploy)
    def app.push_with_retry!; end # Don't actually deploy

    app.deploy do
      assert_equal string, File.read("Gemfile").chomp
      assert_equal false, app.send(:needs_commit?)
    end
  end
end
