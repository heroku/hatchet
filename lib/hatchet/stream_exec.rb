require 'timeout'

module Hatchet
  # runs arbitrary commands within a Heroku process
  class StreamExec
    attr_reader :input, :output, :pid
    TIMEOUT = 1 # seconds to run an arbitrary command on a heroku process like `$ls`

    def initialize(output, input, pid)
      @input  = input
      @output = output
      @pid    = pid
    end

    def write(cmd)
      input.write(cmd)
    rescue Errno::EIO => e
      raise e, "#{e.message} | trying to write '#{cmd}'"
    end

    def run(cmd, timeout = TIMEOUT)
      write(cmd)
      return read(timeout)
    end

    def close
      timeout("closing stream") do
        input.close
        output.close
      end
    ensure
      Process.kill('TERM', pid)   if pid.present?
    end

    # There be dragons - (You're playing with process deadlock)
    #
    # We want to read the whole output of the command
    # First pull all contents from stdout (except we don't know how many there are)
    # So we have to go until our process deadlocks, then we timeout and return the string
    #
    def read(timeout = TIMEOUT)
      str = ""
      while true
        Timeout::timeout(timeout) do
          str << output.readline
        end
      end

      return str
    rescue Timeout::Error, EOFError
      return str
    end
    alias :clear :read

    def timeout(msg = nil, val = TIMEOUT, &block)
      Timeout::timeout(val) do
        yield
      end
    rescue Timeout::Error
      puts "timeout #{msg}" if msg
    end
  end
end
