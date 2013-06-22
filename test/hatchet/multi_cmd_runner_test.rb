require 'test_helper'

class MultiCmdRunnerTest < Test::Unit::TestCase
  def setup
    @buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'
  end

  # slow but needed, there are ghosts in the machine
  # by running common command multiple times we can find them
  def test_multi_repl_commands
    Hatchet::AnvilApp.new("rails3_mri_193", buildpack: @buildpack_path).deploy do |app|
      app.add_database

      rand(3..7).times do
        app.run("bash") do |bash|
          assert_match /Gemfile/, bash.run("ls")
        end
      end

      rand(3..7).times do
        app.run("rails console") do |console|
          assert_match /foofoofoofoofoo/, console.run("'foo' * 5")
          assert_match /hello world/,     console.run("'hello ' + 'world'")
        end
      end
    end
  end
end
