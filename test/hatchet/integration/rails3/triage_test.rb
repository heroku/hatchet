require 'test_helper'

class TriageTest < Test::Unit::TestCase
  def test_foo
    Hatchet::GitApp.new("codetriage").deploy do |app|
      assert true
      assert app.deployed?
      app.run("bash") do |cmd|
        # cmd.run("cd public/assets")
        assert cmd.run("ls public/assets").include?("application.css")
      end
    end
  end
end

