require("spec_helper")
describe "ConfigTest" do
  before { @config = Hatchet::Config.new }

  it("config path for name") do
    expect(@config.path_for_name("rails3_mri_193")).to(eq("repo_fixtures/repos/rails3/rails3_mri_193"))
  end

  it("config dirs") do
    { "repo_fixtures/repos/bundler/no_lockfile" => "https://github.com/sharpstone/no_lockfile.git", "repo_fixtures/repos/default/default_ruby" => "https://github.com/sharpstone/default_ruby.git", "repo_fixtures/repos/rails2/rails2blog" => "https://github.com/sharpstone/rails2blog.git", "repo_fixtures/repos/rails3/rails3_mri_193" => "https://github.com/sharpstone/rails3_mri_193.git" }.each do |key, value|
      assert_include(key, value, @config.dirs)
    end
  end

  it("config repos") do
    { "default_ruby" => "repo_fixtures/repos/default/default_ruby", "no_lockfile" => "repo_fixtures/repos/bundler/no_lockfile", "rails2blog" => "repo_fixtures/repos/rails2/rails2blog", "rails3_mri_193" => "repo_fixtures/repos/rails3/rails3_mri_193" }.each do |key, value|
      assert_include(key, value, @config.repos)
    end
  end

  it("no internal config raises no errors") do
    @config.send(:set_internal_config!, {})
    expect(@config.repo_directory_path).to(eq("./repos"))
  end

  it("github shortcuts") do
    @config.send(:init_config!, "foo" => (["schneems/sextant"]))
    expect(@config.dirs["./repos/foo/sextant"]).to(eq("https://github.com/schneems/sextant.git"))
  end

  private def assert_include(key, value, actual)
    expect(actual[key]).to eq(value), "Expected #{actual.inspect} to include #{{ key => value }} but it did not"
  end
end
