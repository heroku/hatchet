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
