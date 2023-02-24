
require "spec_helper"

describe "DefaultCIBranch" do
  it "doesn't error on empty env" do
    out = DefaultCIBranch.new(env: {}).call
    expect(out).to be_nil
  end

  it "GitHub PRs" do
    out = DefaultCIBranch.new(env: {"GITHUB_HEAD_REF" => "iAmaPR"}).call
    expect(out).to eq("iAmaPR")

    out = DefaultCIBranch.new(env: {"GITHUB_HEAD_REF" => ""}).call
    expect(out).to be_nil
  end

  it "GitHub branches" do
    out = DefaultCIBranch.new(env: {"GITHUB_REF_NAME" => "iAmaBranch"}).call
    expect(out).to eq("iAmaBranch")
  end

  it "heroku" do
    out = DefaultCIBranch.new(env: {"HEROKU_TEST_RUN_BRANCH" => "iAmaBranch"}).call
    expect(out).to eq("iAmaBranch")
  end
end
