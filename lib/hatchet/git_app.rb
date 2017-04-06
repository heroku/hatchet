module Hatchet
  # used for deploying a test app to heroku via git
  class GitApp < App
    def git_repo
      "https://git.heroku.com/#{name}.git"
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
