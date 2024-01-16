require "spec_helper"

describe "CIFourTest" do
  it "error with bad app" do
    string = SecureRandom.hex

    app = Hatchet::GitApp.new("default_ruby")
    app.run_ci do |test_run|
      expect(test_run.output).to_not match(string)
      expect(test_run.output).to match("Installing rake")

      run!("echo 'puts \"#{string}\"' >> Rakefile")
      test_run.run_again

      expect(test_run.output).to match(string)
      expect(test_run.output).to match("Using rake")
      expect(test_run.output).to_not match("Installing rake")
    end
  end

  it "error with bad app" do
    pending("upgrade rails 5 app to newer")

    expect {
      Hatchet::GitApp.new("rails5_ci_fails_no_database", stack: "heroku-18").run_ci { }
    }.to raise_error(/PG::ConnectionBad: could not connect to server/)
  end

  it "error with bad app" do
    @before_deploy_called = false
    @before_deploy_dir_pwd = nil

    before_deploy = -> do
      @before_deploy_called = true
      @before_deploy_dir_pwd = Dir.pwd
    end

    Hatchet::GitApp.new("rails5_ci_fails_no_database", stack: "heroku-18", allow_failure: true, before_deploy: before_deploy).run_ci do |test_run|
      expect(test_run.status).to eq(:errored)
      expect(@before_deploy_dir_pwd).to eq(Dir.pwd)
      expect(@before_deploy_called).to be_truthy
    end

    expect(@before_deploy_dir_pwd).to_not eq(Dir.pwd)
  end
end
