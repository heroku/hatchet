require 'pty'
module Hatchet
  # spawns a process on Heroku, and keeps it open for writing
  # like `heroku run bash`
  class ProcessSpawn
    attr_reader :command, :app, :timeout

    TIMEOUT = 20 # seconds to bring up a heroku command like `heroku run bash`

    def initialize(command, app, timeout = nil)
      @command = command
      @app     = app
      @timeout = timeout || TIMEOUT
    end

    def ready?
      `heroku ps -a #{app.name}`.match(/^run.*up.*`#{command}`/).present?
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

    # Open up PTY (pseudo terminal) to command like `heroku run bash`
    # Wait for the dyno to deploy, then allow user to run arbitrary commands
    #
    def run(&block)
      raise "need app"     unless app.present?
      raise "need command" unless command.present?
      output, input, pid = PTY.spawn("heroku run #{command} -a #{app.name}")
      stream = StreamExec.new(input, output)
      stream.timeout("waiting for spawn", timeout) do
        wait_for_spawn!
      end
      raise "Could not run: #{command}" unless self.ready?
      yield stream
    ensure
      stream.close                if stream.present?
      Process.kill('TERM', pid)   if pid.present?
    end
  end
end