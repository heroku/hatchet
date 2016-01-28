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
      self
    end

    def git_repo
      'http' == ENV['HATCHET_GIT_PROTOCOL'] ?
        "https://git.heroku.com/#{name}.git" :
        "git@heroku.com:#{name}.git"
    end

    def push_without_retry!
      output = `git push #{git_repo} master 2>&1`
      if !$?.success?
        raise FailedDeploy.new(self, "Buildpack: #{@buildpack.inspect}\nRepo: #{git_repo}\n#{output}") unless @allow_failure
      end
      return output
    end
  end
end
