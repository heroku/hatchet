require "spec_helper"

describe "Hatchet::Init" do
  def fake_buildpack_dir
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/bin")
      yield dir
    end
  end
  it "raises an error when not pointing at the right directory" do
    Dir.mktmpdir do |dir|
      expect {
        Hatchet::InitProject.new(dir: dir)
      }.to raise_error(/Must run in a directory with a buildpack/)
    end
  end

      # write_target(target: ".circleci/config.yml", template: "circleci_template.erb")
      # write_target(target: "Gemfile", template: "Gemfile.erb")
      # write_target(target: "hatchet.json", contents: "{}")
      # write_target(target: "hatchet.lock", contents: YAML.dump({}))
      # write_target(target: "spec/spec_helper.rb", template: "spec_helper.erb")
      # write_target(target: "spec/hatchet/buildpack_spec.rb", template: "buildpack_spec.erb")
      # write_target(target: ".github/dependabot.yml", template: "dependabot.erb")

  it "generates files" do
    fake_buildpack_dir do |dir|
      fake_stdout = StringIO.new
      init = Hatchet::InitProject.new(dir: dir, io: fake_stdout)
      init.call

      circle_ci_file = Pathname.new(dir).join(".circleci/config.yml")
      expect(circle_ci_file.read).to match("parallel_split_test")

      %W{
         .circleci/config.yml
         Gemfile
         hatchet.json
         hatchet.lock
         spec/spec_helper.rb
         spec/hatchet/buildpack_spec.rb
         .github/dependabot.yml
         .github/workflows/check_changelog.yml
         .gitignore
      }.each do |path|
        expect(Pathname.new(dir).join(path)).to exist
      end

      expect(fake_stdout.string).to match("Bundle complete")
    end
  end
end
