require 'test_helper'

class GitAppTest < Minitest::Test
  def test_can_deploy_git_app
    Hatchet::GitApp.new("rails5_ruby_schema_format").deploy do |app|
      assert true
      assert_match '2.4.1', app.run("ruby -v")

      app.run("bash") do |cmd|
        # cmd.run("cd public/assets")
        cmd.run("ls public/") {|r| assert_match("assets", r) }
      end
    end
  end
end

