module Hatchet
  class App
    BUILDPACK = nil
    attr_reader :name, :directory

    def initialize(directory, options = {})
      @directory = directory
      @name      = options[:name]      || "test-app-#{Time.now.to_f}".gsub('.', '-')
      @buildpack = options[:buildpack] || "https://github.com/heroku/heroku-buildpack-ruby.git"
    end

    def git_repo
      "git@heroku.com:#{name}.git"
    end

    def run(command, &block)
      ProcessSpawn.new(command, self).run(&block)
    end

    def deployed?
      `heroku ps -a #{name}`.include?("web")
    end

    def setup!
      heroku.post_app(name: name)
      heroku.put_config_vars(name, 'BUILDPACK_URL' => @buildpack)
      @app_is_setup = true
    end

    def push!
      `git push #{git_repo} master`
    end

    def teardown!
      heroku.delete_app(name)
    end

    def deploy(&block)
      Dir.chdir(directory) do
        self.setup!
        self.push!
        block.call(self)
      end
    ensure
      self.teardown! if @app_is_setup
    end

    private
      def heroku
        api_key ||= ENV['HEROKU_API_KEY'] || `heroku auth:token`
        @heroku ||= Heroku::API.new(api_key: api_key)
      end
  end
end