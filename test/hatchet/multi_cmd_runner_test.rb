require 'test_helper'

class MultiCmdRunnerTest < Minitest::Test
  # slow but needed, there are ghosts in the machine
  # by running common command multiple times we can find them
  def test_multi_repl_commands
    Hatchet::GitApp.new("default_ruby").deploy do |app|

      assert_raise(ReplRunner::UnregisteredCommand) do
        app.run("ls", 2) do |ls| # will return right away, should raise error
          ls.run("cat")
        end
      end

      rand(3..7).times do
        app.run("irb") do |console|
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
