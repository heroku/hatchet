module Hatchet
  # used for deploying a test app to heroku via git
  class GitApp < App
    BUILDPACK_URL = "https://github.com/heroku/heroku-buildpack-ruby.git"

    def initialize(directory, options = {})
      @buildpack = options[:buildpack] || options[:buildpack_url] || BUILDPACK_URL
      super
    end

    def setup!
      super
      heroku.put_config_vars(name, 'BUILDPACK_URL' => @buildpack)
    end

    def push!
      output = `git push #{git_repo} master`
      [$?.success?, output]
    end
  end
end
