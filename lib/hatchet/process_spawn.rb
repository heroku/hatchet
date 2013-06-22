require 'pty'
module Hatchet
  # spawns a process on Heroku, and keeps it open for writing
  # like `heroku run bash`
  class ProcessSpawn
    attr_reader :command, :app, :timeout, :pid
    TIMEOUT = 60 # seconds to bring up a heroku command like `heroku run bash`

    def initialize(command, app, timeout = nil)
      raise "need command" unless command.present?
      raise "need app"     unless app.present?
      @command        = "heroku run #{command} -a #{app.name}"
      @ready_regex    = "^run.*up.*#{command}"
      @app            = app
      @timeout        = timeout || TIMEOUT
    end

    def ready?
      @ready ||= `heroku ps -a #{app.name}`.match(/#{@ready_regex}/).present?
    end

    def not_ready?
      !ready?
    end

    def wait_for_spawn!
      while not_ready?
        sleep 1
      end
      return true
    end

    # some REPL's don't sync standard out by default
    # try to do it auto-magically
    def repl_magic(repl)
      case command
      when /rails\s*console/, /\sirb\s/
        # puts "magic for: '#{command}'"
        repl.run("STDOUT.sync = true")
      end
    end

    # Open up PTY (pseudo terminal) to command like `heroku run bash`
    # Wait for the dyno to deploy, then allow user to run arbitrary commands
    def spawn_repl
      output, input, pid = PTY.spawn(command)
      stream = StreamExec.new(output, input, pid)
      repl   = ReplRunner.new(stream)
      stream.timeout("waiting for spawn", timeout) do
        wait_for_spawn!
      end
      raise "Could not run: '#{command}', command took longer than #{timeout} seconds" unless self.ready?

      repl_magic(repl)
      repl.clear # important to get rid of startup info i.e. "booting rails console ..."
      return repl
    end

    def run(&block)
      return `#{command}` if block.blank? # one off command, no block given

      yield repl = spawn_repl
    ensure
      repl.close if repl.present?
    end
  end
end
