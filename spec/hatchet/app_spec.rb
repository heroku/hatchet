require("spec_helper")

describe "AppTest" do
  it "rate throttles `git push` " do
    app = Hatchet::GitApp.new("default_ruby")
    def app.git_push_heroku_yall
      @_git_push_heroku_yall_call_count ||= 0
      @_git_push_heroku_yall_call_count += 1
      if @_git_push_heroku_yall_call_count >= 2
        "Success"
      else
        raise Hatchet::App::FailedDeployError.new(self, "message", output: "Your account reached the API rate limit Please wait a few minutes before making new requests")
      end
    end

    def app.sleep_called?; @sleep_called; end

    def app.what_is_git_push_heroku_yall_call_count; @_git_push_heroku_yall_call_count; end
    app.push_without_retry!

    expect(app.what_is_git_push_heroku_yall_call_count).to be(2)
  end

  it "calls reaper if cannot create an app" do
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    def app.heroku_api_create_app(*args); raise StandardError.new("made you look"); end

    reaper = app.reaper

    def reaper.cycle(app_exception_message: ); @app_exception_message = app_exception_message; end
    def reaper.recorded_app_exception_message; @app_exception_message; end

    expect {
      app.create_app
    }.to raise_error("made you look")

    expect(reaper.recorded_app_exception_message).to match("made you look")
  end

  it "app with default" do
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    expect(app.buildpacks.first).to match("https://github.com/heroku/heroku-buildpack-ruby")
  end

  it "create app with stack" do
    stack = "heroku-16"
    app = Hatchet::App.new("default_ruby", stack: stack)
    app.create_app
    expect(app.platform_api.app.info(app.name)["build_stack"]["name"]).to eq(stack)
  end

  it "marks itself 'finished' when done in block mode" do
    app = Hatchet::Runner.new("default_ruby")

    def app.push_with_retry!; nil; end
    app.deploy do |app|
      expect(app.platform_api.app.info(app.name)["maintenance"]).to be_falsey
    end


    # After the app is updated, there's no guarantee it will still exist
    # so we cannot rely on an api call to determine maintenance mode
    app_update_info = app.instance_variable_get(:"@app_update_info")
    expect(app_update_info["name"]).to eq(app.name)
    expect(app_update_info["maintenance"]).to be_truthy
  end

  it "marks itself 'finished' when done in non-block mode" do
    app = Hatchet::Runner.new("default_ruby")

    def app.push_with_retry!; nil; end
    app.deploy
    expect(app.platform_api.app.info(app.name)["maintenance"]).to be_falsey

    app.teardown!

    # After the app is updated, there's no guarantee it will still exist
    # so we cannot rely on an api call to determine maintenance mode
    app_update_info = app.instance_variable_get(:"@app_update_info")
    expect(app_update_info["name"]).to eq(app.name)
    expect(app_update_info["maintenance"]).to be_truthy
  end

  it "before deploy" do
    @called = false
    @dir = false
    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!
      # do nothing
    end
    app.before_deploy do
      @called = true
      @dir = Dir.pwd
    end
    app.deploy do
      expect(@called).to eq(true)
      expect(@dir).to eq(Dir.pwd)
    end
    expect(@dir).to_not eq(Dir.pwd)
  end

  it "auto commits code" do
    string = "foo#{SecureRandom.hex}"
    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!
      # do nothing
    end
    app.before_deploy do |app|
      expect(app.send(:needs_commit?)).to eq(false)
      `echo "#{string}" > Gemfile`
      expect(app.send(:needs_commit?)).to eq(true)
    end
    app.deploy do
      expect(File.read("Gemfile").chomp).to eq(string)
      expect(app.send(:needs_commit?)).to eq(false)
    end
  end

  it "nested in directory" do
    string = "foo#{SecureRandom.hex}"
    app = Hatchet::App.new("default_ruby")
    def app.push_with_retry!
      # do nothing
    end
    app.in_directory do
      `echo "#{string}" > Gemfile`
      dir = Dir.pwd
      app.deploy do
        expect(File.read("Gemfile").chomp).to eq(string)
        expect(dir).to eq(Dir.pwd)
      end
    end
  end

  it "run" do
    app = Hatchet::GitApp.new("default_ruby")
    app.deploy do
      expect(app.run("ls -a Gemfile 'foo bar #baz'")).to match(/ls: cannot access 'foo bar #baz': No such file or directory\s+Gemfile/)
      expect((0 != $?.exitstatus)).to be_truthy
      sleep(4)
      app.run("ls erpderp", heroku: ({ "exit-code" => (Hatchet::App::SkipDefaultOption) }))
      expect((0 == $?.exitstatus)).to be_truthy
      sleep(4)
      app.run("ls erpderp", heroku: ({ "no-tty" => nil }))
      expect((0 != $?.exitstatus)).to be_truthy
      sleep(4)
      expect(app.run("echo \\$HELLO \\$NAME", raw: true, heroku: ({ "env" => "HELLO=ohai;NAME=world" }))).to match(/ohai world/)
      sleep(4)
      expect(app.run("echo \\$HELLO \\$NAME", raw: true, heroku: ({ "env" => "" }))).to_not match(/ohai world/)
      sleep(4)
      random_name = SecureRandom.hex
      expect(app.run("mkdir foo; touch foo/#{random_name}; ls foo/")).to match(/#{random_name}/)
    end
  end
end
