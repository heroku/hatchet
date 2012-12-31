require 'timeout'
module Hatchet
  # runs arbitrary commands within a Heroku process
  class StreamExec
    attr_reader :input, :output
    TIMEOUT = 1 # seconds to run an arbitrary command on a heroku process like `$ls`

    def initialize(input, output)
      @input  = input
      @output = output
    end

    def run(cmd)
      raise "command expected" if cmd.blank?
      input.write("#{cmd}\n")
      return read(cmd)
    end

    def close
      timeout("closing stream") do
        input.close
        output.close
      end
    end

    # There be dragons - (You're playing with process deadlock)
    #
    # We want to read the whole output of the command
    # First pull all contents from stdout (except we don't know how many there are)
    # So we have to go until our process deadlocks, then we timeout and return the string
    #
    # Example
    #   result = ""
    #   input.write("ls\n")
    #   Timeout::timeout(1) {output.each {|x| result << x}}
    #      Timeout::Error: execution expired
    #   puts result
    #     # => "ls\r\r\napp\tconfig.ru  Gemfile\t LICENSE.txt  public\t script  vendor\r\r\nbin\tdb\t   Gemfile.lock  log\t      Rakefile\t test\r\r\nconfig\tdoc\t   lib\t\t Procfile     README.md  tmp\r\r\n"
    #
    # Now we want to remove the original command ("ls\r\r\n") and return the remainder
    def read(cmd, str = "")
      timeout do
        # this is guaranteed to timeout; output.each will not return
        output.each { |line| str << line }
      end
      str.split("#{cmd}\r\r\n").last
    end

    def timeout(msg = nil, val = TIMEOUT, &block)
      Timeout::timeout(val) do
        yield
      end
    rescue Timeout::Error
      puts "timeout #{msg}" if msg
    end
  end
end

