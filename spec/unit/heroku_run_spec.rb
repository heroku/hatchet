require "spec_helper"

describe "HerokuRun" do
  def fake_app
    app = Object.new
    def app.name; "fake_app"; end
    app
  end

  describe "options" do
    it "escapes by default" do
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: fake_app)
      expect(run_obj.command).to eq("heroku run --app=fake_app --exit-code -- ruby\\ -v")
    end

    it "escapes by default" do
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: fake_app, heroku: { "exit-code" => Hatchet::App::SkipDefaultOption })
      expect(run_obj.command).to eq("heroku run --app=fake_app -- ruby\\ -v")
    end

    it "allows setting switch values by default" do
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: fake_app, heroku: { "no-tty" => nil })
      expect(run_obj.command).to eq("heroku run --app=fake_app --exit-code --no-tty -- ruby\\ -v")
    end

    it "can be used to pass env vars" do
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: fake_app, heroku: { "env" => "HELLO=ohai;NAME=world" })
      expect(run_obj.command).to eq("heroku run --app=fake_app --exit-code --env=HELLO\\=ohai\\;NAME\\=world -- ruby\\ -v")
    end


    it "lets me use raw values" do
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: fake_app, raw: true )
      expect(run_obj.command).to eq("heroku run --app=fake_app --exit-code -- ruby -v")
    end
  end

  describe "retry on empty" do
    before(:all) do
      @app = Hatchet::Runner.new("default_ruby")
      @app.setup!
    end

    after(:all) do
      @app.teardown!
    end

    it "retries 3 times on empty result" do
      stderr = StringIO.new
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: @app, stderr: stderr)

      def run_obj.run_shell!
        # to populate $? with a correct status variable
        `exit 1`
        @result = Hatchet::BashResult.new(stdout: "", stderr: "", status: $?)
        @status = $?
      end

      run_obj.call

      expect(run_obj.instance_variable_get(:@empty_fail_count)).to eq(3)
      expect(stderr.string).to include("now retrying execution")
    end

    it "retries 0 times on NON empty result" do
      stderr = StringIO.new
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: @app, stderr: stderr)

      def run_obj.run_shell!
        # to populate $? with a correct status variable
        `exit 1`
        @result = Hatchet::BashResult.new(stdout: "not empty", stderr: "", status: $?)
        @status = $?
      end

      run_obj.call

      expect(run_obj.instance_variable_get(:@empty_fail_count)).to eq(0)
      expect(run_obj.output).to eq("not empty")
    end

    it "retries 0 times on empty result when disabled" do
      stderr = StringIO.new
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: @app, stderr: stderr, retry_on_empty: false)

      def run_obj.run_shell!
        # to populate $? with a correct status variable
        `exit 1`
        @result = Hatchet::BashResult.new(stdout: "", stderr: "", status: $?)
        @status = $?
      end

      run_obj.call

      expect(run_obj.instance_variable_get(:@empty_fail_count)).to eq(0)
      expect(stderr.string).to_not include("now retrying execution")
    end

    it "retries work when message is delivered via stderr" do
      stderr = StringIO.new
      run_obj = Hatchet::HerokuRun.new("ruby -v", app: @app, stderr: stderr, retry_on_empty: false)

      def run_obj.run_shell!
        @throttle_retry_count ||= 0
        @throttle_retry_count += 1
        @command = "echo 'lol'" if @throttle_retry_count > 1

        super
      end

      run_obj.instance_variable_set(:@command, "ruby -e 'STDERR.puts %Q{reached the API rate limit}'")
      run_obj.call

      expect(run_obj.instance_variable_get(:@throttle_retry_count)).to eq(2)
    end

    it "retries 0 times on empty result when disabled via ENV var" do
      begin
        original_env = ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"]
        ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"] = "1"
        stderr = StringIO.new
        run_obj = Hatchet::HerokuRun.new("ruby -v", app: @app, stderr: stderr)

        def run_obj.run_shell!
          # to populate $? with a correct status variable
          `exit 1`
          @result = Hatchet::BashResult.new(stdout: "", stderr: "", status: $?)
          @status = $?
        end

        run_obj.call

        expect(run_obj.instance_variable_get(:@empty_fail_count)).to eq(0)
        expect(stderr.string).to_not include("now retrying execution")
      ensure
        ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"] = original_env
      end
    end
  end
end

