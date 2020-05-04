require("spec_helper")

describe "AllowFailureGitTest" do
  it "allowed failure" do
    Hatchet::GitApp.new("no_lockfile", allow_failure: true).deploy do |app|
      puts app.output
      expect(app.deployed?).to be_falsey
      expect(app.output).to match("Gemfile.lock required")
    end
  end

  it "failure with no flag" do
    expect { Hatchet::GitApp.new("no_lockfile").deploy }.to(raise_error(Hatchet::App::FailedDeploy))
  end
end
