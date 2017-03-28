require 'shellwords'
require 'platform-api'

module Hatchet
  class App
    HATCHET_BUILDPACK_BASE   = (ENV['HATCHET_BUILDPACK_BASE'] || "https://github.com/heroku/heroku-buildpack-ruby.git")
    HATCHET_BUILDPACK_BRANCH = -> { ENV['HATCHET_BUILDPACK_BRANCH'] || Hatchet.git_branch }
    BUILDPACK_URL = "https://github.com/heroku/heroku-buildpack-ruby.git"

    attr_reader :name, :stack, :directory, :repo_name

    class FailedDeploy < StandardError
      def initialize(app, output)
        msg = "Could not deploy '#{app.name}' (#{app.repo_name}) using '#{app.class}' at path: '#{app.directory}'\n" <<
              " if this was expected add `allow_failure: true` to your deploy hash.\n" <<
              "output:\n" <<
              "#{output}"
        super(msg)
      end
    end

    def initialize(repo_name, options = {})
      @repo_name     = repo_name
      @directory     = config.path_for_name(@repo_name)
      @name          = options[:name]          || "hatchet-t-#{SecureRandom.hex(10)}"
      @stack         = options[:stack]
      @debug         = options[:debug]         || options[:debugging]
      @allow_failure = options[:allow_failure] || false
      @labs          = ([] << options[:labs]).flatten.compact
      @buildpack     = options[:buildpack] || options[:buildpack_url] || [HATCHET_BUILDPACK_BASE, HATCHET_BUILDPACK_BRANCH.call].join("#")
      @reaper        = Reaper.new(heroku)
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
        heroku.put_config_vars(name, key => value)
      end
    end

    def get_config
      heroku.get_config_vars(name).body
    end

    def lab_is_installed?(lab)
      get_labs.any? {|hash| hash["name"] == lab }
    end

    def get_labs
      heroku.get_features(name).body
    end

    def set_labs!
      @labs.each {|lab| set_lab(lab) }
    end

    def set_lab(lab)
      heroku.post_feature(lab, name)
    end

    def add_database(db_name = 'heroku-postgresql:dev', match_val = "HEROKU_POSTGRESQL_[A-Z]+_URL")
      Hatchet::RETRIES.times.retry do
        heroku.post_addon(name, db_name)
        _, value = get_config.detect {|k, v| k.match(/#{match_val}/) }
        set_config('DATABASE_URL' => value)
      end
    end

    # runs a command on heroku similar to `$ heroku run #foo`
    # but programatically and with more control
    def run(cmd_type, command = nil, options = {}, &block)
      command        = cmd_type.to_s if command.nil?
      heroku_options = (options.delete(:heroku) || {}).map {|k,v| "--#{k.to_s.shellescape}=#{v.to_s.shellescape}"}.join(" ")
      heroku_command = "heroku run #{command.to_s.shellescape} -a #{name} #{ heroku_options }"
      bundle_exec do
        if block_given?
          ReplRunner.new(cmd_type, heroku_command, options).run(&block)
        else
          `#{heroku_command}`
        end
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
      !heroku.get_ps(name).body.detect {|ps| ps["process"].include?("web") }.nil?
    end

    def create_app
      3.times.retry do
        begin
          heroku.post_app({ name: name, stack: stack }.delete_if {|k,v| v.nil? })
        rescue Heroku::API::Errors::RequestFailed => e
          @reaper.cycle if e.message.match(/app limit/)
          raise e
        end
      end
    end

    # creates a new heroku app via the API
    def setup!
      return self if @app_is_setup
      puts "Hatchet setup: #{name.inspect} for #{repo_name.inspect}"
      create_app
      set_labs!
      @app_is_setup = true
      self
    end
    alias :setup :setup!

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
      Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r("#{directory}/.", "#{tmpdir}/.")
        Dir.chdir(tmpdir) do
          yield directory
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
        block.call(self, heroku, output) if block_given?
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
    end

    def output
      @output
    end

    def api_key
      @api_key ||= ENV['HEROKU_API_KEY'] || bundle_exec {`heroku auth:token`.chomp }
    end

    def heroku
      @heroku ||= Heroku::API.new(api_key: api_key)
    end

    def run_ci(timeout: 300, &block)
      Hatchet::RETRIES.times.retry do
        result       = create_pipeline
        @pipeline_id = result["id"]
      end

      # create_app
      # platform_api.pipeline_coupling.create(app: name, pipeline: @pipeline_id, stage: "development")
      test_run = TestRun.new(token:      api_key,
                             buildpacks: @buildpack,
                             timeout:    timeout,
                             app:        self,
                             pipeline:   @pipeline_id)

      Hatchet::RETRIES.times.retry do
        test_run.create_test_run
      end
      test_run.wait!(&block)
    ensure
      delete_pipeline(@pipeline_id) if @pipeline_id
    end

    def pipeline_id
      @pipeline_id
    end

    def create_pipeline
      platform_api.pipeline.create(name: @name)
    end

    def source_get_url
      create_source
      @source_get_url
    end

    def create_source
      @create_source ||= begin
        result = platform_api.source.create
        @source_get_url = result["source_blob"]["get_url"]
        @source_put_url = result["source_blob"]["put_url"]
        @source_put_url
      end
    end

    def delete_pipeline(pipeline_id)
      platform_api.pipeline.delete(pipeline_id)
    end

    def platform_api
      @platform_api ||= PlatformAPI.connect_oauth(api_key)
    end

    private
    # if someone uses bundle exec
    def bundle_exec
      if defined?(Bundler)
        Bundler.with_clean_env do
          yield
        end
      else
        yield
      end
    end
  end
end

