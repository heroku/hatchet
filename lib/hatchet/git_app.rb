module Hatchet
  # used for deploying a test app to heroku via git
  class GitApp < App
    HATCHET_BUILDPACK_BASE   = (ENV['HATCHET_BUILDPACK_BASE'] || "https://github.com/heroku/heroku-buildpack-ruby.git")
    HATCHET_BUILDPACK_BRANCH = -> { ENV['HATCHET_BUILDPACK_BRANCH'] || Hatchet.git_branch }
    BUILDPACK_URL = "https://github.com/heroku/heroku-buildpack-ruby.git"

    def initialize(directory, options = {})
      @buildpack = options[:buildpack] || options[:buildpack_url] || [HATCHET_BUILDPACK_BASE, HATCHET_BUILDPACK_BRANCH.call].join("#")
      super
    end

    def setup!
      super
      heroku.put_config_vars(name, 'BUILDPACK_URL' => @buildpack)
    end

    def git_repo
      "git@heroku.com:#{name}.git"
    end

    def push!
      output = `git push #{git_repo} master 2>&1`
      if !$?.success?
        raise FailedDeploy.new(self, "Buildpack: #{@buildpack.inspect}\nRepo: #{git_repo}\n#{output}") unless @allow_failure
      end
      return output
    end
  end
end
