require 'test_helper'

class ConfigTest < Test::Unit::TestCase
  def setup
    @config = Hatchet::Config.new
  end

  def test_config_path_for_name
    assert_equal 'test/fixtures/repos/rails3/codetriage', @config.path_for_name('codetriage')
  end

  def test_config_dirs
    expected_dirs = { "test/fixtures/repos/rails3/codetriage" => "git@github.com:codetriage/codetriage.git",
                      "test/fixtures/repos/rails2/rails2blog" => "git@github.com:heroku/rails2blog.git" }
    assert_equal expected_dirs, @config.dirs
  end

  def test_config_repos
    expected_repos = { "codetriage" => "test/fixtures/repos/rails3/codetriage",
                       "rails2blog" => "test/fixtures/repos/rails2/rails2blog" }
    assert_equal expected_repos, @config.repos
  end
end
