require 'open3'
require 'timeout'

module Hatchet
  class BashResult
    attr_reader :stdout, :stderr, :status, :status_obj

    def initialize(stdout:, stderr:, status:, set_global_status: false)
      @stdout = stdout
      @stderr = stderr
      @status_obj = status
      @status = @status_obj.exitstatus
      return unless set_global_status
      # we're now populating `$?` by hand for any callers that rely on that
      if @status_obj.signaled?
        # termination of 'heroku run' from our TERM signal
        # a signaled program will not have an exit status
        # the shell just represents that case as 128+$signal, so e.g. 128+15=143 for SIGTERM
        # the correct behavior for a program is to terminate itself using the signal it received
        # this will also produce the correct $? contents (signaled? again, termsig set, no exitstatus)
        `kill -#{@status_obj.termsig} $$`
      else
        # the dyno exited and the CLI is reporting that back as an exit status
        `exit #{@status}`
      end
    end

    # @return [Boolean]
    def success?
      @status_obj.success?
    end

    def failed?
      !success?
    end

    # Testing helper methods
    def include?(value)
      stdout.include?(value)
    end

    def match?(value)
      stdout.match?(value)
    end

    def match(value)
      stdout.match(value)
    end
  end

  # Used for running Heroku commands
  #
  # Example:
  #
  #   run_obj = HerokuRun.new("ruby -v", app: app).call
  #   puts run_obj.output #=> "ruby 2.7.1p83 (2020-03-31 revision a0c7c23c9c) [x86_64-linux]"
  #   puts run_obj.status.success? #=> true
  #
  # There's a bug in specs sometimes where App#run will return an empty
  # value. When that's detected then the command will be re-run. This can be
  # optionally disabled by setting `retry_on_empty: false` if you're expecting
  # the command to be empty.
  #
  class HerokuRun
    class HerokuRunEmptyOutputError < RuntimeError; end
    class HerokuRunTimeoutError < RuntimeError; end

    attr_reader :command

    def initialize(
      command,
      app: ,
      heroku: {},
      retry_on_empty: !ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"],
      retry_delay: 0,
      raw: false,
      stderr: $stderr,
      timeout: 0)

      @raw = raw
      @app = app
      @timeout = timeout
      @command = build_heroku_command(command, heroku || {})
      @retry_on_empty = retry_on_empty
      @retry_delay = retry_delay
      @stderr = stderr
      @result = nil
      @dyno_id = nil
      @empty_fail_count = 0
      @timeout_fail_count = 0
    end

    def result
      raise "You must run `call` on this object first" unless @result
      @result
    end

    def output
      result.stdout
    end

    def status
      result
      @status
    end

    def call
      begin
        execute!
      rescue HerokuRunEmptyOutputError => e
        if @retry_on_empty and @empty_fail_count < 3
          @empty_fail_count += 1
          message = e.message
          message << "\n#{caller.join("\n")}"
          message << "\nThis was failed attempt ##{@empty_fail_count}, now retrying execution."
          message << "\nTo disable retries, pass in `retry_on_empty: false` or set HATCHET_DISABLE_EMPTY_RUN_RETRY=1 globally."
          @stderr.puts message
          sleep(@retry_delay) # without run_multi, this will prevent occasional "can only run one free dyno" errors
          retry
        else
          raise # we are out of retries
        end
      rescue HerokuRunTimeoutError => e
        @app.platform_api.dyno.stop(@app.name, @dyno_id) if @dyno_id
        if @timeout_fail_count < 3
          @timeout_fail_count += 1
          message = e.message
          message << "\n#{caller.join("\n")}"
          message << "\nThis was failed attempt ##{@timeout_fail_count}, now retrying execution."
          message << "\nTo disable retries, pass in `timeout: 0` or set HATCHET_DEFAULT_RUN_TIMEOUT=0 globally."
          @stderr.puts message
          sleep(@retry_delay) # without run_multi, this will prevent occasional "can only run one free dyno" errors
          retry
        else
          raise # we are out of retries
        end
      end

      self
    end

    private def execute!
      ShellThrottle.new(platform_api: @app.platform_api).call do |throttle|
        run_shell!
        throw(:throttle) if @result.stderr.match?(/reached the API rate limit/)
        raise HerokuRunTimeoutError.new "Run #{@dyno_id} with command #{@command} timed out after #{@timeout} seconds, stopping dyno.\nstderr until moment of termination was:\n#{@result.stderr}\nstdout until moment of termination was: #{@result.stdout}\nReleases: #{@app.releases}" if @result.status_obj.signaled? # program got terminated by our SIGTERM, raise
        raise HerokuRunEmptyOutputError.new "Empty output from run #{@dyno_id} with command #{@command}.\nReleases: #{@app.releases}" if @result.stdout.empty?
      end
    end

    private def run_shell!
      r_stdout = ""
      r_stderr = ""
      r_status = nil
      @dyno_id = nil
      Open3.popen3(@command) do |stdin, stdout, stderr, wait_thread|
        begin
          Timeout.timeout(@timeout) do
            Thread.new do
              begin
                until stdout.eof? do
                  r_stdout += stdout.gets
                end
              rescue IOError # eof? and gets race condition
              end
            end
            Thread.new do
              begin
                until stderr.eof? do
                  r_stderr += line = stderr.gets
                  if !@dyno_id and run = line.match(/, (run\.\d+)/)
                    @dyno_id = run.captures.first
                  end
                end
              rescue IOError # eof? and gets race condition
              end
            end
          end
          r_status = wait_thread.value # wait for termination
        rescue Timeout::Error
          Process.kill("TERM", wait_thread.pid)
          r_status = wait_thread.value # wait for termination
        end
      end
      @result = BashResult.new(stdout: r_stdout, stderr: r_stderr, status: r_status, set_global_status: true)
      @status = $?
    end

    private def build_heroku_command(command, options = {})
      command = command.shellescape unless @raw

      default_options = { "app" => @app.name, "exit-code" => nil }
      heroku_options_array = (default_options.merge(options)).map do |k,v|
        # This was a bad interface decision
        next if v == Hatchet::App::SkipDefaultOption # for forcefully removing e.g. --exit-code, a user can pass this

        arg = "--#{k.to_s.shellescape}"
        arg << "=#{v.to_s.shellescape}" unless v.nil? # nil means we include the option without an argument
        arg
      end

      "heroku run #{heroku_options_array.compact.join(' ')} -- #{command}"
    end
  end
end
