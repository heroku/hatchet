require 'open3'

module Hatchet
  class BashResult
    attr_reader :stdout, :stderr, :status

    def initialize(stdout:, stderr:, status:, set_global_status: false)
      @stdout = stdout
      @stderr = stderr
      @status = status.respond_to?(:exitstatus) ? status.exitstatus : status.to_i
      `exit #{@status}` if set_global_status
    end

    # @return [Boolean]
    def success?
      @status == 0
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

    attr_reader :command

    def initialize(
      command,
      app: ,
      heroku: {},
      retry_on_empty: !ENV["HATCHET_DISABLE_EMPTY_RUN_RETRY"],
      raw: false,
      stderr: $stderr)

      @raw = raw
      @app = app
      @command = build_heroku_command(command, heroku || {})
      @retry_on_empty = retry_on_empty
      @stderr = stderr
      @result = nil
      @empty_fail_count = 0
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
          message = String.new("Empty output from command #{@command}, retrying the command.")
          message << "\nTo disable pass in `retry_on_empty: false` or set HATCHET_DISABLE_EMPTY_RUN_RETRY=1 globally"
          message << "\nfailed_count: #{@empty_fail_count}"
          message << "\nreleases: #{@app.releases}"
          message << "\n#{caller.join("\n")}"
          @stderr.puts message
          retry
        end
      end

      self
    end

    private def execute!
      ShellThrottle.new(platform_api: @app.platform_api).call do |throttle|
        run_shell!
        throw(:throttle) if @result.stderr.match?(/reached the API rate limit/)
        raise HerokuRunEmptyOutputError if @result.stdout.empty?
      end
    end

    private def run_shell!
      r_stdout = ""
      r_stderr = ""
      Open3.popen3(@command) do |stdin, stdout, stderr, wait_thread|
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
              r_stderr += stderr.gets
            end
          rescue IOError # eof? and gets race condition
          end
        end
        r_status = wait_thread.value # wait for termination
      end
      @result = BashResult.new(stdout: r_stdout, stderr: r_stderr, status: r_status, set_global_status: true)
      # FIXME: usage of $? does not allow a test to distinguish between a TERM of the 'heroku run' itself, or inside the dyno
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
