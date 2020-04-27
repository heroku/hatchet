require("spec_helper")
describe "LocalRepoTest" do
  it "in directory fork" do
    env_name = SecureRandom.hex
    ENV[env_name] = env_name
    Hatchet::App.new("default_ruby").in_directory_fork do
      ENV.delete(env_name) # Does not affect parent env
      expect(ENV[env_name]).to be_nil
    end

    expect(ENV[env_name]).to eq(env_name)
  end

  it "repos checked into git" do
    begin
      app = Hatchet::App.new("repo_fixtures/different-folder-for-checked-in-repos/default_ruby")
      app.in_directory do
        expect(Dir.exist?(".git")).to eq(false)
        app.setup!
        expect(Dir.exist?(".git")).to eq(true)
      end
    ensure
      app.teardown! if app
    end
  end
end
