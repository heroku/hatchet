require 'test_helper'

class ConfigTest < Minitest::Test

  def setup
    @config = Hatchet::Config.new
  end

  def test_config_path_for_name
    assert_equal 'test/fixtures/repos/rails3/rails3_mri_193', @config.path_for_name('rails3_mri_193')
  end

  def test_config_dirs
    {
      "test/fixtures/repos/bundler/no_lockfile"   => "https://github.com/sharpstone/no_lockfile.git",
      "test/fixtures/repos/default/default_ruby"  => "https://github.com/sharpstone/default_ruby.git",
      "test/fixtures/repos/rails2/rails2blog"     => "https://github.com/sharpstone/rails2blog.git",
      "test/fixtures/repos/rails3/rails3_mri_193" => "https://github.com/sharpstone/rails3_mri_193.git"
     }.each do |key, value|
       assert_include(key, value, @config.dirs)
     end
  end

  def test_config_repos
    {
      "default_ruby"   => "test/fixtures/repos/default/default_ruby",
      "no_lockfile"    => "test/fixtures/repos/bundler/no_lockfile",
      "rails2blog"     => "test/fixtures/repos/rails2/rails2blog",
      "rails3_mri_193" => "test/fixtures/repos/rails3/rails3_mri_193"
     }.each do |key, value|
       assert_include(key, value, @config.repos)
     end
  end

  def test_no_internal_config_raises_no_errors
    # assert no_raise
    @config.send :set_internal_config!, {}
    assert_equal './repos', @config.repo_directory_path
  end

  def test_github_shortcuts
    @config.send :init_config!, {"foo" => ["schneems/sextant"]}
    assert_equal("https://github.com/schneems/sextant.git", @config.dirs["./repos/foo/sextant"])
  end
  private

    def assert_include(key, value, actual)
      assert_equal value, actual[key], "Expected #{actual.inspect} to include #{ {key => value } } but it did not"
    end
end

