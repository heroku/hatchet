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
      fixture_dir = "repo_fixtures/different-folder-for-checked-in-repos/default_ruby"
      app = Hatchet::App.new(fixture_dir)
      def app.push_with_retry!; end

      expect(Dir.exist?("#{fixture_dir}/.git")).to be_falsey

      app.deploy do
        expect(Dir.exist?(".git")).to be_truthy
      end
    end
  end
end
