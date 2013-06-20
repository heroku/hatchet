require 'test_helper'

class StreamExecTest < Test::Unit::TestCase
  def test_local_irb_stream
    command            = "irb"
    output, input, pid = PTY.spawn(command)
    stream             = Hatchet::StreamExec.new(input, output, pid)
    stream.run("STDOUT.sync = true\n")
    assert_equal "1+1\r\n => 2 \r\n", stream.run("1+1\n")
  end
end

