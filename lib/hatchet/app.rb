module Hatchet
  class App
    attr_reader :name, :directory

    def initialize(repo_name, options = {})
      @directory = config.path_for_name(repo_name)
      @name      = options[:name]  || "test-app-#{Time.now.to_f}".gsub('.', '-')
      @debug     = options[:debug] || options[:debugging]
    end

    # config is read only, should be threadsafe
    def self.config
      @config ||= Config.new
    end

    def config
      self.class.config
    end

    # runs a command on heroku similar to `$ heroku run #foo`
    # but programatically and with more control
    def run(command, timeout = nil, &block)
      ProcessSpawn.new(command, self, timeout).run(&block)
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

    # creates a new heroku app via the API
    def setup!
      heroku.post_app(name: name)
      @app_is_setup = true
    end

    def push!
      raise NotImplementedError
    end

    def teardown!
      return false unless @app_is_setup
      if debugging?
        puts "Debugging App:#{name}"
        return false
      end
      heroku.delete_app(name)
    end

    # creates a new app on heroku, "pushes" via anvil or git
    # then yields to self so you can call self.run or
    # self.deployed?
    def deploy(&block)
      Dir.chdir(directory) do
        self.setup!
        result, output = self.push!
        block.call(self, heroku, output)
      end
    ensure
      self.teardown!
    end

    private
      def api_key
        @api_key ||= ENV['HEROKU_API_KEY'] || `heroku auth:token`.chomp
      end

      def heroku
        @heroku ||= Heroku::API.new(api_key: api_key)
      end
  end
end

