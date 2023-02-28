require("spec_helper")

describe "AppTest" do
  it "annotates rspec expectation failures" do
    app = Hatchet::Runner.new("default_ruby")
    error = nil
    begin
      app.annotate_failures do
        expect(true).to eq(false)
      end
    rescue RSpec::Expectations::ExpectationNotMetError => e
      error = e
    end

    expect(error.message).to include(app.name)
  end

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

    def reaper.destroy_older_apps(*args, **kwargs, &block); @app_exception_message = true; end
    def reaper.clean_old_was_called?; @app_exception_message; end

    expect {
      app.create_app
    }.to raise_error("made you look")

    expect(reaper.clean_old_was_called?).to be_truthy
  end

  it "app with default" do
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    expect(app.buildpacks.first).to match("https://github.com/heroku/heroku-buildpack-ruby")
  end

  it "default_buildpack is only computed once" do
    expect(Hatchet::App.default_buildpack.object_id).to eq(Hatchet::App.default_buildpack.object_id)
  end

  it "create app with stack" do
    stack = "heroku-18"
    app = Hatchet::App.new("default_ruby", stack: stack)
    app.create_app
    expect(app.platform_api.app.info(app.name)["build_stack"]["name"]).to eq(stack)
  end

  it "create app with HATCHET_DEFAULT_STACK set" do
    begin
      original_default_stack = ENV["HATCHET_DEFAULT_STACK"]
      default_stack = "heroku-18"
      ENV["HATCHET_DEFAULT_STACK"] = default_stack
      app = Hatchet::App.new("default_ruby")
      app.create_app
      expect(app.platform_api.app.info(app.name)["build_stack"]["name"]).to eq(default_stack)
    ensure
      ENV["HATCHET_DEFAULT_STACK"] = original_default_stack
    end
  end

  describe "before deploy" do
    it "dir" do
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

    it "prepend" do
      @value = ""
      app = Hatchet::App.new("default_ruby")
      def app.push_with_retry!; end
      app.before_deploy do
        @value << "there"
      end

      app.before_deploy(:prepend) do
        @value << "hello "
      end
      app.deploy do
      end

      expect(@value).to eq("hello there")
    end

    it "append" do
      @value = ""
      app = Hatchet::App.new("default_ruby")
      def app.push_with_retry!; end
      app.before_deploy do
        @value << "there"
      end

      app.before_deploy(:append) do
        @value << " hello"
      end
      app.deploy do
      end

      expect(@value).to eq("there hello")
    end

    it "replace" do
      @value = ""
      app = Hatchet::App.new("default_ruby")
      def app.push_with_retry!; end
      app.before_deploy do
        @value << "there"
      end

      app.before_deploy(:replace) do
        @value << "hello"
      end
      app.deploy do
      end

      expect(@value).to eq("hello")
    end
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
      app.run_multi("ls") { |out| expect(out).to include("Gemfile"); @run_count.add(1); }
      app.run_multi("blerg -v") { |_, status| expect(status.success?).to be_falsey; @run_count.add(1); }
      app.run_multi("ruby -v") do |out, status|
        expect(out).to include("ruby")
        expect(status.success?).to be_truthy

        @run_count.add(1)
      end
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
