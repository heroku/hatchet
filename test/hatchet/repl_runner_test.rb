require 'test_helper'
require 'stringio'

class ReplRunnerTest < Test::Unit::TestCase

  def test_returns_full_output_if_command_not_found
    command            = "irb"
    input              = StringIO.new("bar")
    bogus_output       = StringIO.new("foo")
    stream             = Hatchet::StreamExec.new(bogus_output, input, 1)
    repl               = Hatchet::ReplRunner.new(stream)
    repl.write("1+1")
    assert_equal bogus_output.string, repl.read("1+1")

    Hatchet::CommandParser.any_instance.expects(:parse).times(Hatchet::ReplRunner::RETRIES)
    Hatchet::CommandParser.any_instance.stubs(:to_s)
    repl.write("1+1")
    repl.read("1+1")
  end
end
