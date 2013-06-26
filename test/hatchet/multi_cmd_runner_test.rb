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

      assert_raise ReplRunner::UnregisteredCommand do
        app.run("ls", 2) do |ls| # will return right away, should raise error
          ls.run("cat")
        end
      end

      rand(3..7).times do
        app.run("rails console") do |console|
          console.run("`ls`")
          console.run("'foo' * 5")          {|r| assert_match "foofoofoofoofoo", r }
          console.run("'hello ' + 'world'") {|r| assert_match "hello world", r }
        end
      end

      rand(3..7).times do
        app.run("bash") do |bash|
          bash.run("ls") { |r| assert_match "Gemfile", r }
        end
      end

    end
  end
end
