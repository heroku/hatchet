require 'test_helper'

class GitAppTest < Test::Unit::TestCase
  def test_can_deploy_git_app
    Hatchet::GitApp.new("rails3_mri_193", buildpack: "https://github.com/heroku/heroku-buildpack-ruby.git").deploy do |app|
      assert true
      assert_match '1.9.3', app.run("ruby -v")

      app.run("bash") do |cmd|
        # cmd.run("cd public/assets")
        cmd.run("ls public/assets") {|r| assert_match "application.css", r}
      end
    end
  end
end

