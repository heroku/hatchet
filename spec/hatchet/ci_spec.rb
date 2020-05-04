require "spec_helper"

describe "CIFourTest" do
  it "error with bad app" do
    string = SecureRandom.hex

    Hatchet::GitApp.new("default_ruby").run_ci do |test_run|
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
    expect {
      Hatchet::GitApp.new("rails5_ci_fails_no_database").run_ci { }
    }.to raise_error(/PG::ConnectionBad: could not connect to server/)
  end

  it "error with bad app" do
    @before_deploy_called = false
    @before_deploy_dir_pwd = nil

    before_deploy = -> do
      @before_deploy_called = true
      @before_deploy_dir_pwd = Dir.pwd
    end

    Hatchet::GitApp.new("rails5_ci_fails_no_database", allow_failure: true, before_deploy: before_deploy).run_ci do |test_run|
      expect(test_run.status).to eq(:errored)
      expect(@before_deploy_dir_pwd).to eq(Dir.pwd)
      expect(@before_deploy_called).to be_truthy
    end

    expect(@before_deploy_dir_pwd).to_not eq(Dir.pwd)
  end

  it "ci create app with stack" do
    app = Hatchet::GitApp.new("rails5_ruby_schema_format")
    app.run_ci do |test_run|
      expect(test_run.output).to match("Ruby buildpack tests completed successfully")
      expect(test_run.status).to eq(:succeeded)
      expect(app.pipeline_id).to_not be_nil

      api_rate_limit = app.api_rate_limit.call
      couplings = api_rate_limit.pipeline_coupling.list_by_pipeline(app.pipeline_id)
      coupled_app = api_rate_limit.app.info(couplings.first["app"]["id"])
      expect(coupled_app["name"]).to eq(app.name)
    end
    expect(app.pipeline_id).to be_nil
  end
end
