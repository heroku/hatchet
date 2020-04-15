require 'securerandom'
require 'shellwords'
require 'platform-api'
require 'tmpdir'

module Hatchet
  class App
    HATCHET_BUILDPACK_BASE   = (ENV['HATCHET_BUILDPACK_BASE'] || "https://github.com/heroku/heroku-buildpack-ruby.git")
    HATCHET_BUILDPACK_BRANCH = -> { ENV['HATCHET_BUILDPACK_BRANCH'] || ENV['HEROKU_TEST_RUN_BRANCH'] || Hatchet.git_branch }
    BUILDPACK_URL = "https://github.com/heroku/heroku-buildpack-ruby.git"

    attr_reader :name, :stack, :directory, :repo_name, :app_config, :buildpacks

    class FailedDeploy < StandardError
      def initialize(app, output)
        msg = "Could not deploy '#{app.name}' (#{app.repo_name}) using '#{app.class}' at path: '#{app.directory}'\n" <<
              " if this was expected add `allow_failure: true` to your deploy hash.\n" <<
              "output:\n" <<
              "#{output}"
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
      @already_in_dir = nil
      @app_is_setup = nil

      @before_deploy = before_deploy
      @app_config    = config
      @reaper        = Reaper.new(api_rate_limit: api_rate_limit)
    end

    def self.default_buildpack
      [HATCHET_BUILDPACK_BASE, HATCHET_BUILDPACK_BRANCH.call].join("#")
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
      Hatchet::RETRIES.times.retry do
        # heroku.post_addon(name, plan_name)
        api_rate_limit.call.addon.create(name, plan: plan_name )
        _, value = get_config.detect {|k, v| k.match(/#{match_val}/) }
        set_config('DATABASE_URL' => value)
      end
    end

    # runs a command on heroku similar to `$ heroku run #foo`
    # but programatically and with more control
    def run(cmd_type, command = nil, options = {}, &block)
      command        = cmd_type.to_s if command.nil?
      default_options = { "app" => name, "exit-code" => nil }
      heroku_options = (default_options.merge(options.delete(:heroku) || {})).map do |k,v|
        next if v == Hatchet::App::SkipDefaultOption # for forcefully removing e.g. --exit-code, a user can pass this
        arg = "--#{k.to_s.shellescape}"
        arg << "=#{v.to_s.shellescape}" unless v.nil? # nil means we include the option without an argument
        arg
      end.join(" ")
      heroku_command = "heroku run #{heroku_options} -- #{command}"
      if block_given?
        require 'repl_runner'
        ReplRunner.new(cmd_type, heroku_command, options).run(&block)
      else
        `#{heroku_command}`
      end
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
      # !heroku.get_ps(name).body.detect {|ps| ps["process"].include?("web") }.nil?
      api_rate_limit.call.formation.list(name).detect {|ps| ps["type"] == "web"}
    end

    def create_app
      3.times.retry do
        begin
          # heroku.post_app({ name: name, stack: stack }.delete_if {|k,v| v.nil? })
          hash = { name: name, stack: stack }
          hash.delete_if { |k,v| v.nil? }
          api_rate_limit.call.app.create(hash)
        rescue => e
          @reaper.cycle
          raise e
        end
      end
    end

    def update_stack(stack_name)
      @stack = stack_name
      api_rate_limit.call.app.update(name, build_stack: @stack)
    end

    # creates a new heroku app via the API
    def setup!
      return self if @app_is_setup
      puts "Hatchet setup: #{name.inspect} for #{repo_name.inspect}"
      create_git_repo! unless is_git_repo?
      create_app
      set_labs!
      buildpack_list = @buildpacks.map { |pack| { buildpack: pack } }
      api_rate_limit.call.buildpack_installation.update(name, updates: buildpack_list)
      set_config @app_config

      call_before_deploy
      @app_is_setup = true
      self
    end
    alias :setup :setup!

    def before_deploy(&block)
      raise "block required" unless block
      @before_deploy = block

      self
    end

    def commit!
      local_cmd_exec!('git add .; git commit -m next')
    end

    def push_without_retry!
      raise NotImplementedError
    end

    def teardown!
      return false unless @app_is_setup
      if debugging?
        puts "Debugging App:#{name}"
        return false
      end
      @reaper.cycle
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

    # creates a new app on heroku, "pushes" via anvil or git
    # then yields to self so you can call self.run or
    # self.deployed?
    # Allow deploy failures on CI server by setting ENV['HATCHET_RETRIES']
    def deploy(&block)
      in_directory do
        self.setup!
        self.push_with_retry!
        block.call(self, api_rate_limit.call, output) if block_given?
      end
    ensure
      self.teardown!
    end

    def push
      max_retries = @allow_failure ? 1 : RETRIES
      max_retries.times.retry do |attempt|
        begin
          @output = self.push_without_retry!
        rescue StandardError => error
          puts retry_error_message(error, attempt, max_retries)
          raise error
        end
      end
    end
    alias :push! :push
    alias :push_with_retry  :push
    alias :push_with_retry! :push_with_retry

    def retry_error_message(error, attempt, max_retries)
      attempt += 1
      return "" if attempt == max_retries
      msg = "\nRetrying failed Attempt ##{attempt}/#{max_retries} to push for '#{name}' due to error: \n"<<
            "#{error.class} #{error.message}\n  #{error.backtrace.join("\n  ")}"
      return msg
    end

    def output
      @output
    end

    def api_key
      @api_key ||= ENV['HEROKU_API_KEY'] || `heroku auth:token`.chomp
    end

    def heroku
      raise "Not supported, use `platform_api` instead."
    end

    def run_ci(timeout: 300, &block)
      Hatchet::RETRIES.times.retry do
        result       = create_pipeline
        @pipeline_id = result["id"]
      end

      # when the CI run finishes, the associated ephemeral app created for the test run internally gets removed almost immediately
      # the system then sees a pipeline with no apps, and deletes it, also almost immediately
      # that would, with bad timing, mean our test run info poll in wait! would 403, and/or the delete_pipeline at the end
      # that's why we create an app explictly (or maybe it already exists), and then associate it with with the pipeline
      # the app will be auto cleaned up later
      self.setup!
      Hatchet::RETRIES.times.retry do
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
      in_directory do
        call_before_deploy

        Hatchet::RETRIES.times.retry do
          test_run.create_test_run
        end
        test_run.wait!(&block)
      end
    ensure
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
    end

    def platform_api
      puts "Deprecated: use `api_rate_limit.call` instead of platform_api"
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
      return unless @before_deploy
      raise "before_deploy: #{@before_deploy.inspect} must respond to :call"  unless @before_deploy.respond_to?(:call)
      raise "before_deploy: #{@before_deploy.inspect} must respond to :arity" unless @before_deploy.respond_to?(:arity)

      if @before_deploy.arity == 1
        @before_deploy.call(self)
      else
        @before_deploy.call
      end

      commit! if needs_commit?
    end
  end
end

