require("spec_helper")

describe "AllowFailureGitTest" do
  describe "release failures" do
    let(:release_fail_proc) {
      Proc.new do
        File.open("Procfile", "w+") do |f|
          f.write <<~EOM
            release: echo "failing on release" && exit 1
          EOM
        end
      end
    }

    it "is marked as a failure if the release fails" do
      expect {
        Hatchet::GitApp.new("default_ruby", before_deploy: release_fail_proc, retries: 2).deploy {}
      }.to raise_error { |error|
        expect(error).to be_a(Hatchet::App::FailedReleaseError)
        expect(error.message).to_not match("Everything up-to-date")
      }
    end

    it "works when failure is allowed" do
      Hatchet::GitApp.new("default_ruby", before_deploy: release_fail_proc, allow_failure: true).deploy do |app|
        expect(app.output).to match("failing on release")
      end
    end
  end

  it "allowed failure" do
    Hatchet::GitApp.new("no_lockfile", allow_failure: true).deploy do |app|
      expect(app.deployed?).to be_falsey
      expect(app.output).to match("Gemfile.lock required")
    end
  end

  it "failure with no flag" do
    expect {
      Hatchet::GitApp.new("no_lockfile").deploy {}
    }.to(raise_error(Hatchet::App::FailedDeploy))
  end
end
