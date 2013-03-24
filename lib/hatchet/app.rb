module Hatchet
  class App
    attr_reader :name, :directory

    def initialize(directory, options = {})
      @directory = directory
      @name      = options[:name] || "test-app-#{Time.now.to_f}".gsub('.', '-')
      @debug     = options[:debug]
    end

    def git_repo
      "git@heroku.com:#{name}.git"
    end

    # runs a command on heroku similar to `$ heroku run #foo`
    # but programatically and with more control
    def run(command, &block)
      ProcessSpawn.new(command, self).run(&block)
    end

    # set debug: true when creating app if you don't want it to be
    # automatically destroyed, useful for debugging...bad for app limits.
    # turn on global debug by setting HATCHET_DEBUG=true in the env
    def debug?
      @debug || ENV['HATCHET_DEBUG'] || false
    end

    def not_debugging?
      !debug?
    end

    def deployed?
      !heroku.get_ps(name).body.detect {|ps| ps["process"].include?("web") }.nil?
    end

    def setup!
      heroku.post_app(name: name)
      @app_is_setup = true
    end

    def push!
      raise NotImplementedError
    end

    def teardown!
      heroku.delete_app(name)
    end

    def deploy(&block)
      Dir.chdir(directory) do
        self.setup!
        result, output = self.push!
        block.call(self, heroku, output)
      end
    ensure
      self.teardown! if @app_is_setup && not_debugging?
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
