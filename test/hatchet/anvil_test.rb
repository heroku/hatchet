require 'test_helper'

class AnvilTest < Test::Unit::TestCase
  def setup
    @buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'
  end

  def test_deploy
    Hatchet::AnvilApp.new("rails3_mri_193", buildpack: @buildpack_path).deploy do |app, heroku, output|
      assert true

      assert_match '1.9.3', app.run("ruby -v")
      app.run("bash") do |cmd|
        cmd.run("cat Gemfile")      {|r| assert_match "gem 'pg'", r}
        cmd.run("ls public/assets") {|r| assert_match "application.css", r}
      end
    end
  end
end
