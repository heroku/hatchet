require "spec_helper"
require 'yaml'

describe "LockTest" do
  before(:all) do
    puts(`bundle exec hatchet lock`)
  end

  it "app with failure can be locked to prior commit" do
    Hatchet::GitApp.new("lock_fail").deploy do |app|
      expect(app.deployed?).to be_truthy
    end
  end

  it "app with failure can be locked to master" do
    lock = YAML.load_file("hatchet.lock")
    name, branch = lock.select { |k, v| k.end_with?("lock_fail_master") }.first

    expect(name).to eq("repo_fixtures/repos/lock/lock_fail_master")
    expect(branch).to eq("master")
  end

  it "app with failure can be locked to main" do
    lock = YAML.load_file("hatchet.lock")
    name, branch = lock.select { |k, v| k.end_with?("lock_fail_main") }.first

    expect(name).to eq("repo_fixtures/repos/lock/lock_fail_main")
    expect(branch).to eq("main")
  end
end

describe "isolated lock tests" do
  it "works when there's no hatchet.lock" do
    Dir.mktmpdir do |dir|
      dir = Pathname.new(dir)

      dir.join("hatchet.json").open("w+") do |f|
        f.puts %Q{{ "foo": ["sharpstone/lock_fail_main_default_is_master"] }}
      end

      output = `cd #{dir} && hatchet lock 2>&1`

      raise "Expected cmd `hatchet lock` to succeed, but it did not: #{output}" unless $?.success?
      expect(output).to include("locking")

      lockfile_contents = dir.join('hatchet.lock').read
      expect(lockfile_contents).to include("repos/foo/lock_fail_main_default_is_master")
    end
  end

  it "works when a project is locked to main but the default branch is master" do
    Dir.mktmpdir do |dir|
      dir = Pathname.new(dir)

      dir.join("hatchet.json").open("w+") do |f|
        f.puts %Q{{ "foo": ["sharpstone/lock_fail_main_default_is_master"] }}
      end

      dir.join("hatchet.lock").open("w+") do |f|
        f.puts <<~EOM
        ---
        - - "./repos/foo/lock_fail_main_default_is_master"
          - main
        EOM
      end

      output = `cd #{dir} && hatchet install 2>&1`

      raise "Expected cmd `hatchet install` to succeed, but it did not:\n#{output}" unless $?.success?
      expect(output).to include("Installing")

      lockfile_contents = dir.join('hatchet.lock').read
      contents = YAML.safe_load(lockfile_contents).to_h
      expect(contents).to eq({"./repos/foo/lock_fail_main_default_is_master" => "main"})

      contents.each do |repo_dir, commit_or_branch|
        expect(`cd #{dir.join(repo_dir)} && git describe --contains --all HEAD`).to match("main")
      end
    end
  end
end
