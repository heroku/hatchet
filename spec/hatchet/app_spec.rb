require("spec_helper")

describe "AppTest" do
  it "does not modify local files by mistake" do
    Dir.mktmpdir do |dir_1|
      app = Hatchet::Runner.new(dir_1)
      Dir.mktmpdir do |dir_2|
        Dir.chdir(dir_2) do
          FileUtils.touch("foo.txt")

          app.setup!
        end

        entries_array = Dir.entries(dir_2)
        entries_array -= ["..", ".", "foo.txt"]
        expect(entries_array).to be_empty


        entries_array = Dir.entries(dir_1)
        entries_array -= ["..", ".", "foo.txt"]
        expect(entries_array).to be_empty
      end
    end
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
    skip("Must set HATCHET_EXPENSIVE_MODE") unless ENV["HATCHET_EXPENSIVE_MODE"]

    app = Hatchet::GitApp.new("default_ruby", run_multi: true)
    app.deploy do
      expect(app.run("ls -a Gemfile 'foo bar #baz'")).to match(/ls: cannot access 'foo bar #baz': No such file or directory\s+Gemfile/)
      expect((0 != $?.exitstatus)).to be_truthy

      app.run("ls erpderp", heroku: ({ "exit-code" => (Hatchet::App::SkipDefaultOption) }))
      expect((0 == $?.exitstatus)).to be_truthy

      app.run("ls erpderp", heroku: ({ "no-tty" => nil }))
      expect((0 != $?.exitstatus)).to be_truthy

      expect(app.run("echo \\$HELLO \\$NAME", raw: true, heroku: ({ "env" => "HELLO=ohai;NAME=world" }))).to match(/ohai world/)

      expect(app.run("echo \\$HELLO \\$NAME", raw: true, heroku: ({ "env" => "" }))).to_not match(/ohai world/)

      random_name = SecureRandom.hex
      expect(app.run("mkdir foo; touch foo/#{random_name}; ls foo/")).to match(/#{random_name}/)
    end
  end

  class AtomicCount
    attr_reader :value

    def initialize(value)
      @value = value
      @mutex = Mutex.new
    end

    # In MRI the `+=` is not atomic, it is two seperate virtual machine
    # instructions. To protect against race conditions, we can lock with a mutex
    def add(val)
      @mutex.synchronize do
        @value += val
      end
    end
  end

  it "run multi" do
    skip("Must set HATCHET_EXPENSIVE_MODE") unless ENV["HATCHET_EXPENSIVE_MODE"]

    @run_count = AtomicCount.new(0)
    app = Hatchet::GitApp.new("default_ruby", run_multi: true)
    app.deploy do
      app.run_multi("ls") { |out| expect(out).to include("Gemfile"); @run_count.add(1) }
      app.run_multi("blerg -v") { |_, status| expect(status.success?).to be_falsey; @run_count.add(1) }
      app.run_multi("ruby -v") do |out, status|
        expect(out).to include("ruby")
        expect(status.success?).to be_truthy

        @run_count.add(1)
      end

      expect(app.platform_api.formation.list(app.name).detect {|ps| ps["type"] == "web"}["size"].downcase).to_not eq("free")
    end

    # After the deploy block exits `teardown!` is called
    # this ensures all `run_multi` commands have exited and the dyno should be scaled down
    expect(@run_count.value).to eq(3)
  end

  describe "running concurrent tests in different examples works" do
    # This is not a great pattern if we're running tests via a parallel runner
    #
    # For example this will be guaranteed to be called, not just once, but at least once for every process
    # that needs to run a test. In the best case it will only fire once, in the worst case it will fire N times
    # if there are N tests. It is effectively the same as a `before(:each)`
    #
    # Documented here: https://github.com/grosser/parallel_split_test/pull/22/files
    before(:all) do
      skip("Must set HATCHET_EXPENSIVE_MODE") unless ENV["HATCHET_EXPENSIVE_MODE"]

      @app = Hatchet::GitApp.new("default_ruby", run_multi: true)
      @app.deploy
    end

    after(:all) do
      @app.teardown! if @app
    end

    it "test one" do
      expect(@app.run("ls")).to include("Gemfile")
      expect(@app.platform_api.formation.list(@app.name).detect {|ps| ps["type"] == "web"}["size"].downcase).to_not eq("free")
    end

    it "test two" do
      expect(@app.run("ruby -v")).to include("ruby")
      expect(@app.platform_api.formation.list(@app.name).detect {|ps| ps["type"] == "web"}["size"].downcase).to_not eq("free")
    end
  end
end
