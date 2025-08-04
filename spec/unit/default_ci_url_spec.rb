
require "spec_helper"

describe "DefaultCIUrl" do
  it "doesn't error on missing vars" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar"}).call
    expect(out).to be_nil
  end

  it "GitHub PRs" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/pull/123/merge", "GITHUB_SHA" => "c0ffeeee"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/c0ffeeee.tar.gz")
  end

  it "GitHub branches" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/heads/main", "GITHUB_SHA" => "600dd065"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/600dd065.tar.gz")
  end

  it "GitHub tags" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/tags/v123", "GITHUB_SHA" => "f0cacc1a"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/f0cacc1a.tar.gz")
  end

  it "custom GitHub installs" do
    out = DefaultCIUrl.new(env: {"GITHUB_SERVER_URL" => "https://githubenterprise.example.org", "GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/heads/main", "GITHUB_SHA" => "600dd065"}).call
    expect(out).to eq("https://githubenterprise.example.org/foo/bar/archive/600dd065.tar.gz")
  end

  it "with only a GITHUB_REF and no GITHUB_SHA" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/heads/main"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/refs/heads/main.tar.gz")
  end

  it "with only a GITHUB_REF and empty GITHUB_SHA" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/heads/main", "GITHUB_SHA" => "" }).call
    expect(out).to eq("https://github.com/foo/bar/archive/refs/heads/main.tar.gz")
  end

  it "with only a GITHUB_SHA and no GITHUB_REF" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_SHA" => "dabad000"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/dabad000.tar.gz")
  end

  it "with only a GITHUB_SHA and empty GITHUB_REF" do
    out = DefaultCIUrl.new(env: {"GITHUB_REPOSITORY" => "foo/bar", "GITHUB_REF" => "refs/heads/somebranch"}).call
    expect(out).to eq("https://github.com/foo/bar/archive/refs/heads/somebranch.tar.gz")
  end
end
