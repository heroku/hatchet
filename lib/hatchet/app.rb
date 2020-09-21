require 'securerandom'
require 'shellwords'
require 'platform-api'
require 'tmpdir'

module Hatchet
  class App
    HATCHET_BUILDPACK_BASE = -> {
      ENV.fetch('HATCHET_BUILDPACK_BASE') {
        warn "ENV HATCHET_BUILDPACK_BASE is not set. It currently defaults to the ruby buildpack. In the future this env var will be required"
        "https://github.com/heroku/heroku-buildpack-ruby.git"
      }
    }
    HATCHET_BUILDPACK_BRANCH = -> { ENV['HATCHET_BUILDPACK_BRANCH'] || ENV['HEROKU_TEST_RUN_BRANCH'] || Hatchet.git_branch }

    attr_reader :name, :stack, :directory, :repo_name, :app_config, :buildpacks, :reaper, :max_retries_count

    class FailedDeploy < StandardError; end

    class FailedDeployError < FailedDeploy
      attr_reader :output

      def initialize(app, message, output: )
        @output = output
        msg = "Could not deploy '#{app.name}' (#{app.repo_name}) using '#{app.class}' at path: '#{app.directory}'\n"
        msg << "if this was expected add `allow_failure: true` to your deploy hash.\n"
        msg << "#{message}\n"
        msg << "output:\n"
        msg << "#{output}"
        super(msg)
      end
    end

    class FailedReleaseError < FailedDeploy
      attr_reader :output

      def initialize(app, message, output: )
        @output = output
        msg = "Could not release '#{app.name}' (#{app.repo_name}) using '#{app.class}' at path: '#{app.directory}'\n"
        msg << "if this was expected add `allow_failure: true` to your deploy hash.\n"
        msg << "#{message}\n"
        msg << "output:\n"
        msg << "#{output}"
        super(msg)
      end
    end

    SkipDefaultOption = Object.new

    def initialize(repo_name,
                   stack: "",
                   name: default_name,
                   debug: nil,
                   debugging: nil,
                   allow_failure: false,
                   labs: [],
                   buildpack: nil,
                   buildpacks: nil,
                   buildpack_url: nil,
                   before_deploy: nil,
                   run_multi: ENV["HATCHET_RUN_MULTI"],
                   retries: RETRIES,
                   config: {}
                  )
      @repo_name     = repo_name
      @directory     = self.config.path_for_name(@repo_name)
      @name          = name
      @stack         = stack
      @debug         = debug || debugging
      @allow_failure = allow_failure
      @labs          = ([] << labs).flatten.compact
      @buildpacks    = buildpack || buildpacks || buildpack_url || self.class.default_buildpack
      @buildpacks    = Array(@buildpacks)
      @buildpacks.map! {|b| b == :default ? self.class.default_buildpack : b}
      @run_multi = run_multi
      @max_retries_count = retries

      if run_multi && !ENV["HATCHET_EXPENSIVE_MODE"]
        raise "You're attempting to enable `run_multi: true` mode, but have not enabled `HATCHET_EXPENSIVE_MODE=1` env var to verify you understand the risks"
      end
      @run_multi_array = []
      @already_in_dir = nil
      @app_is_setup = nil

      @before_deploy_array = []
      @before_deploy_array << before_deploy if before_deploy
      @app_config    = config
      @reaper        = Reaper.new(api_rate_limit: api_rate_limit)
    end

    def self.default_buildpack
      [HATCHET_BUILDPACK_BASE.call, HATCHET_BUILDPACK_BRANCH.call].join("#")
    end

    def allow_failure?
      @allow_failure
    end

    # config is read only, should be threadsafe
    def self.config
      @config ||= Config.new
    end

    def config
      self.class.config
    end

    def set_config(options = {})
      options.each do |key, value|
        # heroku.put_config_vars(name, key => value)
        api_rate_limit.call.config_var.update(name, key => value)
      end
    end

    def get_config
      # heroku.get_config_vars(name).body
      api_rate_limit.call.config_var.info_for_app(name)
    end

    def lab_is_installed?(lab)
      get_labs.any? {|hash| hash["name"] == lab }
    end

    def get_labs
      # heroku.get_features(name).body
      api_rate_limit.call.app_feature.list(name)
    end

    def set_labs!
      @labs.each {|lab| set_lab(lab) }
    end

    def set_lab(lab)
      # heroku.post_feature(lab, name)
      api_rate_limit.call.app_feature.update(name, lab, enabled: true)
    end

    def add_database(plan_name = 'heroku-postgresql:dev', match_val = "HEROKU_POSTGRESQL_[A-Z]+_URL")
      max_retries_count.times.retry do
        # heroku.post_addon(name, plan_name)
        api_rate_limit.call.addon.create(name, plan: plan_name )
        _, value = get_config.detect {|k, v| k.match(/#{match_val}/) }
        set_config('DATABASE_URL' => value)
      end
    end

    DefaultCommand = Object.new
    # runs a command on heroku similar to `$ heroku run #foo`
    # but programatically and with more control
    def run(cmd_type, command = DefaultCommand, options = {}, &block)
      case command
      when Hash
        options.merge!(command)
        command = cmd_type.to_s
      when nil
        STDERR.puts "Calling App#run with an explicit nil value in the second argument is deprecated."
        STDERR.puts "You can pass in a hash directly as the second argument now.\n#{caller.join("\n")}"
        command = cmd_type.to_s
      when DefaultCommand
        command = cmd_type.to_s
      else
        command = command.to_s
      end

      heroku_command = build_heroku_command(command, options)

      allow_run_multi! if @run_multi

      output = ""

      ShellThrottle.new(platform_api: @platform_api).call do |throttle|
        output = `#{heroku_command}`
        throw(:throttle) if output.match?(/reached the API rate limit/)
      end

      return output
    end

    private def build_heroku_command(command, options = {})
      command = command.shellescape unless options.delete(:raw)

      default_options = { "app" => name, "exit-code" => nil }
      heroku_options = (default_options.merge(options.delete(:heroku) || {})).map do |k,v|
        next if v == Hatchet::App::SkipDefaultOption # for forcefully removing e.g. --exit-code, a user can pass this
        arg = "--#{k.to_s.shellescape}"
        arg << "=#{v.to_s.shellescape}" unless v.nil? # nil means we include the option without an argument
        arg
      end.join(" ")

      "heroku run #{heroku_options} -- #{command}"
    end

    private def allow_run_multi!
      raise "Must explicitly enable the `run_multi: true` option. This requires scaling up a dyno and is not free, it may incur charges on your account" unless @run_multi

      @run_multi_is_setup ||= platform_api.formation.update(name, "web", {"size" => "Standard-1X"})
    end


    # Allows multiple commands to be run concurrently in the background.
    #
    # WARNING! Using the feature requres that the underlying app is not on the "free" Heroku
    # tier. This requires scaling up the dyno which is not free. If an app is
    # scaled up and left in that state it can incur large costs.
    #
    # Enabling this feature should be done with extreme caution.
    #
    # Example:
    #
    #    Hatchet::Runner.new("default_ruby", run_multi: true)
    #      app.run_multi("ls") { |out| expect(out).to include("Gemfile") }
    #      app.run_multi("ruby -v") { |out| expect(out).to include("ruby") }
    #    end
    #
    # This example will run `heroku run ls` as well as `ruby -v` at the same time in the background.
    # The return result will be yielded to the block after they finish running.
    #
    # Order of execution is not guaranteed.
    #
    # If you need to assert a command was successful, you can yield a second status object like this:
    #
    #    Hatchet::Runner.new("default_ruby", run_multi: true)
    #      app.run_multi("ls") do |out, status|
    #        expect(status.success?).to be_truthy
    #        expect(out).to include("Gemfile")
    #      end
    #      app.run_multi("ruby -v") do |out, status|
    #        expect(status.success?).to be_truthy
    #        expect(out).to include("ruby")
    #      end
    #    end
    def run_multi(command, options = {}, &block)
      raise "Block required" if block.nil?
      allow_run_multi!

      run_thread = Thread.new do
        heroku_command = build_heroku_command(command, options)

        out = nil
        status = nil
        ShellThrottle.new(platform_api: @platform_api).call do |throttle|
          out = `#{heroku_command}`
          throw(:throttle) if output.match?(/reached the API rate limit/)
          status = $?
        end

        yield out, status

        # if block.arity == 1
        #   block.call(out)
        # else
        #   block.call(out, status)
        # end
      end
      run_thread.abort_on_exception = true

      @run_multi_array << run_thread

      true
    end

    # set debug: true when creating app if you don't want it to be
    # automatically destroyed, useful for debugging...bad for app limits.
    # turn on global debug by setting HATCHET_DEBUG=true in the env
    def debug?
      @debug || ENV['HATCHET_DEBUG'] || false
    end
    alias :debugging? :debug?

    def not_debugging?
      !debug?
    end
    alias :no_debug? :not_debugging?

    def deployed?
      api_rate_limit.call.formation.list(name).detect {|ps| ps["type"] == "web"}
    end

    def create_app
      3.times.retry do
        begin
          hash = { name: name, stack: stack }
          hash.delete_if { |k,v| v.nil? }
          heroku_api_create_app(hash)
        rescue => e
          @reaper.cycle(app_exception_message: e.message)
          raise e
        end
      end
    end

    private def heroku_api_create_app(hash)
      api_rate_limit.call.app.create(hash)
    end

    def update_stack(stack_name)
      @stack = stack_name
      api_rate_limit.call.app.update(name, build_stack: @stack)
    end

    # creates a new heroku app via the API
    def setup!
      return self if @app_is_setup
      puts "Hatchet setup: #{name.inspect} for #{repo_name.inspect}"
      create_app
      set_labs!
      buildpack_list = @buildpacks.map { |pack| { buildpack: pack } }
      api_rate_limit.call.buildpack_installation.update(name, updates: buildpack_list)
      set_config @app_config

      @app_is_setup = true
      self
    end
    alias :setup :setup!

    private def in_dir_setup!
      setup!
      raise "Error you're in #{Dir.pwd} and might accidentally modify your disk contents" unless @already_in_dir
      @in_dir_setup ||= begin
        create_git_repo! unless is_git_repo?
        call_before_deploy
        true
      end
    end

    def before_deploy(behavior = :default, &block)
      raise "block required" unless block

      case behavior
      when :default, :replace
        if @before_deploy_array.any? && behavior == :default
          STDERR.puts "Calling App#before_deploy multiple times will overwrite the contents. If you intended this: use `App#before_deploy(:replace)`"
          STDERR.puts "In the future, calling this method with no arguements will default to `App#before_deploy(:append)` behavior.\n#{caller.join("\n")}"
        end

        @before_deploy_array.clear
        @before_deploy_array << block
      when :prepend
        @before_deploy_array = [block] + @before_deploy_array
      when :append
        @before_deploy_array << block
      else
        raise "Unrecognized behavior: #{behavior.inspect}, valid inputs are :append, :prepend, and :replace"
      end

      self
    end

    def commit!
      local_cmd_exec!('git add .; git commit --allow-empty -m next')
    end

    def push_without_retry!
      raise NotImplementedError
    end

    def teardown!
      return false unless @app_is_setup

      if @run_multi_is_setup
        @run_multi_array.map(&:join)
        platform_api.formation.update(name, "web", {"size" => "free"})
      end

    ensure
      @app_update_info = platform_api.app.update(name, { maintenance: true }) if @app_is_setup
      @reaper.cycle if @app_is_setup
    end

    def in_directory(directory = self.directory)
      yield directory and return if @already_in_dir

      Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r("#{directory}/.", "#{tmpdir}/.")
        Dir.chdir(tmpdir) do
          @already_in_dir = true
          yield directory
          @already_in_dir = false
        end
      end
    end

    # A safer alternative to in_directory
    # this method is used to run code that may mutate the
    # current process anything run in this block is executed
    # in a different fork
    def in_directory_fork(&block)
      Tempfile.create("stdout") do |tmp_file|
        pid = fork do
          $stdout.reopen(tmp_file, "w")
          $stderr.reopen(tmp_file, "w")
          $stdout.sync = true
          $stderr.sync = true
          in_directory do |dir|
            yield dir
          end
          Kernel.exit!(0) # needed for https://github.com/seattlerb/minitest/pull/683
        end
        Process.waitpid(pid)

        if $?.success?
          puts File.read(tmp_file)
        else
          raise File.read(tmp_file)
        end
      end
    end

    def deploy(&block)
      in_directory do
        in_dir_setup!
        self.push_with_retry!
        block.call(self, api_rate_limit.call, output) if block_given?
      end
    ensure
      self.teardown! if block_given?
    end

    def push
      retry_count = allow_failure? ? 1 : max_retries_count
      retry_count.times.retry do |attempt|
        begin
          @output = self.push_without_retry!
        rescue StandardError => error
          puts retry_error_message(error, attempt) unless retry_count == 1
          raise error
        end
      end
    end
    alias :push! :push
    alias :push_with_retry  :push
    alias :push_with_retry! :push_with_retry

    def retry_error_message(error, attempt)
      attempt += 1
      return "" if attempt == max_retries_count
      msg = "\nRetrying failed Attempt ##{attempt}/#{max_retries_count} to push for '#{name}' due to error: \n"<<
            "#{error.class} #{error.message}\n  #{error.backtrace.join("\n  ")}"
      return msg
    end

    def output
      @output
    end

    def api_key
      @api_key ||= ENV['HEROKU_API_KEY'] ||= `heroku auth:token`.chomp
    end

    def heroku
      raise "Not supported, use `platform_api` instead."
    end

    def run_ci(timeout: 300, &block)
      in_directory do
        max_retries_count.times.retry do
          result       = create_pipeline
          @pipeline_id = result["id"]
        end

        # when the CI run finishes, the associated ephemeral app created for the test run internally gets removed almost immediately
        # the system then sees a pipeline with no apps, and deletes it, also almost immediately
        # that would, with bad timing, mean our test run info poll in wait! would 403, and/or the delete_pipeline at the end
        # that's why we create an app explictly (or maybe it already exists), and then associate it with with the pipeline
        # the app will be auto cleaned up later
        in_dir_setup!
        max_retries_count.times.retry do
          couple_pipeline(@name, @pipeline_id)
        end

        test_run = TestRun.new(
          token:          api_key,
          buildpacks:     @buildpacks,
          timeout:        timeout,
          app:            self,
          pipeline:       @pipeline_id,
          api_rate_limit: api_rate_limit
        )

        max_retries_count.times.retry do
          test_run.create_test_run
        end
        test_run.wait!(&block)
      end
    ensure
      teardown! if block_given?
      delete_pipeline(@pipeline_id) if @pipeline_id
      @pipeline_id = nil
    end

    def pipeline_id
      @pipeline_id
    end

    def create_pipeline
      api_rate_limit.call.pipeline.create(name: @name)
    end

    def couple_pipeline(app_name, pipeline_id)
      api_rate_limit.call.pipeline_coupling.create(app: app_name, pipeline: pipeline_id, stage: "development")
    end

    def source_get_url
      create_source
      @source_get_url
    end

    def create_source
      @create_source ||= begin
        result = api_rate_limit.call.source.create
        @source_get_url = result["source_blob"]["get_url"]
        @source_put_url = result["source_blob"]["put_url"]
        @source_put_url
      end
    end

    def delete_pipeline(pipeline_id)
      api_rate_limit.call.pipeline.delete(pipeline_id)
    rescue Excon::Error::Forbidden
      warn "Error deleting pipeline id: #{pipeline_id.inspect}, status: 403"
      # Means the pipeline likely doesn't exist, not sure why though
    end

    def platform_api
      api_rate_limit
      return @platform_api
    end

    def api_rate_limit
      @platform_api   ||= PlatformAPI.connect_oauth(api_key, cache: Moneta.new(:Null))
      @api_rate_limit ||= ApiRateLimit.new(@platform_api)
    end

    private def needs_commit?
      out = local_cmd_exec!('git status --porcelain').chomp

      return false if out.empty?
      true
    end

    private def is_git_repo?
      `git rev-parse --git-dir > /dev/null 2>&1`
      $?.success?
    end

    private def local_cmd_exec!(cmd)
      out = `#{cmd}`
      raise "Command: #{cmd} failed: #{out}" unless $?.success?
      out
    end

    private def create_git_repo!
      local_cmd_exec!('git init; git add .; git commit -m "init"')
    end

    private def default_name
      "#{Hatchet::APP_PREFIX}#{SecureRandom.hex(5)}"
    end

    private def call_before_deploy
      return unless @before_deploy_array.any?

      @before_deploy_array.each do |block|
        raise "before_deploy: #{block.inspect} must respond to :call"  unless block.respond_to?(:call)
        raise "before_deploy: #{block.inspect} must respond to :arity" unless block.respond_to?(:arity)

        if block.arity == 1
          block.call(self)
        else
          block.call
        end
      end

      commit! if needs_commit?
    end
  end
end

require_relative 'shell_throttle.rb'
