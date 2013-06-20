# takes a StringExec class and attempts to parse commands out of it
module Hatchet
  class ReplRunner
    TIMEOUT = 1
    RETRIES = 10

    attr_accessor :repl

    def initialize(repl, command_parser_klass = CommandParser)
      @repl                 = repl
      @command_parser_klass = command_parser_klass
    end

    def command_parser_klass
      @command_parser_klass
    end

    # adds a newline cause thats what most repl-s need to run command
    def write(cmd)
      repl.write("#{cmd}\n")
    end

    def run(cmd, options = {})
      timeout = options[:timeout] || TIMEOUT
      retries = options[:retries] || RETRIES

      write(cmd)
      read(cmd, timeout, retries)
    end

    def clear
      repl.clear
    end

    def close
      repl.close
    end

    # take in a command like "ls", and tries to find it in the output
    # of the repl (StreamExec)
    # Example
    #  output, input, pid = PTY.spawn('sh')
    #  stream             = StreamExec.new(input, output)
    #  repl_runner = ReplRunner.new(stream)
    #  repl_runner.write("ls\n")
    #  repl_runner.read
    #     # => "app\tconfig.ru  Gemfile\t LICENSE.txt  public\t script  vendor\r\r\nbin\tdb\t   Gemfile.lock  log\t      Rakefile\t test\r\r\nconfig\tdoc\t   lib\t\t Procfile     README.md  tmp\r\r\n"
    #
    # if the command "ls" is not found, repl runner will continue to retry grabbing more output
    def read(cmd, timeout = TIMEOUT, retries = RETRIES)
      str = ""
      command_parser = command_parser_klass.new(cmd)
      retries.times.each do
        next if command_parser.has_valid_output?
        str << repl.read(timeout)
        command_parser.parse(str)
      end
      return command_parser.to_s
    end
  end
end
