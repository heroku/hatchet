require 'test_helper'

class AppTest < Minitest::Test
  def test_app_with_default
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    assert_match "https://github.com/heroku/heroku-buildpack-ruby", app.buildpacks.first
  end

  def test_create_app_with_stack
    stack = "heroku-16"
    app = Hatchet::App.new("default_ruby", stack: stack)
    app.create_app
    assert_equal stack, app.platform_api.app.info(app.name)["build_stack"]["name"]
  end

  def test_before_deploy
    @called = false
    @dir    = false

    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!; end # Don't actually deploy

    app.before_deploy do
      @called = true
      @dir    = Dir.pwd
    end

    app.deploy do
      assert_equal true,    @called
      assert_equal Dir.pwd, @dir
    end

    refute_equal Dir.pwd, @dir
  end

  def test_auto_commits_code
    string = "foo#{SecureRandom.hex}"

    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!; end # Don't actually deploy

    app.before_deploy do |app|
      assert_equal false, app.send(:needs_commit?)
      `echo "#{string}" > Gemfile`
      assert_equal true, app.send(:needs_commit?)
    end
    app.deploy do
      assert_equal string, File.read("Gemfile").chomp
      assert_equal false, app.send(:needs_commit?)
    end
  end


  def test_nested_in_directory
    string = "foo#{SecureRandom.hex}"

    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!; end # Don't actually deploy

    app.in_directory do
      `echo "#{string}" > Gemfile`
      dir = Dir.pwd

      app.deploy do
        assert_equal string, File.read("Gemfile").chomp
        assert_equal Dir.pwd, dir
      end
    end
  end

  def test_run
    app = Hatchet::GitApp.new("default_ruby")
    app.deploy do
      assert_match(/ls: cannot access 'foo bar #baz': No such file or directory\s+Gemfile/, app.run("ls -a Gemfile 'foo bar #baz'"))
      assert (0 != $?.exitstatus) # $? is from the app.run use of backticks
      sleep(4) # Dynos don't exit right away and free dynos can't have more than one running at a time, wait before calling `run` again

      app.run("ls erpderp", { :heroku => { "exit-code" => Hatchet::App::SkipDefaultOption } } )
      assert (0 == $?.exitstatus) # $? is from the app.run use of backticks, but we asked the CLI not to return the program exit status by skipping the default "exit-code" option
      sleep(4)

      app.run("ls erpderp", { :heroku => { "no-tty" => nil } } )
      assert (0 != $?.exitstatus) # $? is from the app.run use of backticks
      sleep(4)

      assert_match(/ohai world/, app.run('echo \$HELLO \$NAME', { raw: true, :heroku => { "env" => "HELLO=ohai;NAME=world" } } ))
      sleep(4)

      refute_match(/ohai world/, app.run('echo \$HELLO \$NAME', { raw: true, :heroku => { "env" => "" } } ))
      sleep(4)

      random_name = SecureRandom.hex
      assert_match(/#{random_name}/, app.run("mkdir foo; touch foo/#{random_name}; ls foo/"))
    end
  end
end
