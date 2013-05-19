require 'test_helper'

class AnvilTest < Test::Unit::TestCase
  def test_deploy
    Dir.chdir('test/fixtures/builpacks/null-buildpack') do
      Hatchet::AnvilApp.new("rails3-hatchet-dev").deploy do |app|
        assert true
        app.run("bash") do |cmd|
          # cmd.run("cd public/assets")

          assert cmd.run("cat Gemfile").include?("gem 'pg'")

          # deploying with null buildpack, no assets should be compiled
          refute cmd.run("ls public/assets").include?("application.css")
        end
      end
    end
  end
end


