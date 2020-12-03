require "open3"
require "timeout"

module Hatchet
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
      @output = ""
      @status = nil
      @dyno_id = nil
      @empty_fail_count = 0
      @timeout_fail_count = 0
    end

    def output
      raise "You must run `call` on this object first" unless @status
      @output
    end

    def status
      raise "You must run `call` on this object first" unless @status
      @status
    end

    def call
      begin
        execute!
      rescue HerokuRunEmptyOutputError => e
        if @retry_on_empty and @empty_fail_count < 3
          @empty_fail_count += 1
          message = String.new("Empty output from run #{@dyno_id} with command #{@command}, retrying...")
          message << "\nTo disable pass in `retry_on_empty: false` or set HATCHET_DISABLE_EMPTY_RUN_RETRY=1 globally"
          message << "\nfailed_count: #{@empty_fail_count}"
          message << "\nreleases: #{@app.releases}"
          message << "\n#{caller.join("\n")}"
          @stderr.puts message
          sleep(@retry_delay) # without run_multi, this will prevent occasional "can only run one free dyno" errors
          retry
        end
      rescue HerokuRunTimeoutError => e
        if @timeout_fail_count < 3
          @timeout_fail_count += 1
          message = String.new("Run #{@dyno_id} with command #{@command} timed out after #{@timeout} seconds, retrying...")
          message << "\nOutput until moment of termination was: #{@output}"
          message << "\nTo disable pass in `timeout: 0` or set HATCHET_DEFAULT_RUN_TIMEOUT=0 globally"
          message << "\nfailed_count: #{@timeout_fail_count}"
          message << "\nreleases: #{@app.releases}"
          message << "\n#{caller.join("\n")}"
          @stderr.puts message
          sleep(@retry_delay) # without run_multi, this will prevent occasional "can only run one free dyno" errors
          retry
        end
      end

      self
    end

    private def execute!
      ShellThrottle.new(platform_api: @app.platform_api).call do |throttle|
        run_shell!
        raise HerokuRunTimeoutError if @status.signaled? # program got terminated by our SIGTERM, raise
        raise HerokuRunEmptyOutputError if @output.empty?
        throw(:throttle) if output.match?(/reached the API rate limit/)
      end
    end

    private def run_shell!
      @output = ""
      @dyno_id = nil
      Open3.popen3(@command) do |stdin, stdout, stderr, wait_thread|
        begin
          Timeout.timeout(@timeout) do
            Thread.new do
              begin
                until stdout.eof? do
                  @output += stdout.gets
                end
              rescue IOError # eof? and gets race condition
              end
            end
            Thread.new do
              begin
                until stderr.eof? do
                  @stderr.puts line = stderr.gets
                  if !@dyno_id and run = line.match(/, (run\.\d+)/)
                    @dyno_id = run.captures.first
                  end
                end
              rescue IOError # eof? and gets race condition
              end
            end
            @status = wait_thread.value # wait for termination
          end
        rescue Timeout::Error
          Process.kill("TERM", wait_thread.pid)
          @status = wait_thread.value # wait for termination
        end
      end
      # re-set $? for tests that rely on us previously having used backticks
       # FIXME: usage of $? in tests is very likely not threadsafe, and does not allow a test to distinguish between a TERM of the 'heroku run' itself, or inside the dyno
      # this should be part of a proper interface to the run result instead but that's a breaking change
      # remove this now that App#run has :return_obj => true?
      if @status.signaled?
        # termination of 'heroku run' from our TERM signal
        # a signaled program will not have an exit status
        # the shell just represents that case as 128+$signal, so e.g. 128+15=143 for SIGTERM
        # the correct behavior for a program is to terminate itself using the signal it received
        # this will also produce the correct $? contents (signaled? again, termsig set, no exitstatus)
        `kill -#{status.termsig} $$`
      else
        # the dyno exited and the CLI is reporting that back as an exit status
        `exit #{status.exitstatus}`
      end
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
