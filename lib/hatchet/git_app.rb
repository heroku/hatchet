module Hatchet
  # used for deploying a test app to heroku via git
  class GitApp < App
    def git_repo
      "https://git.heroku.com/#{name}.git"
    end


    def push_without_retry!
      output = ""

      ShellThrottle.new(platform_api: @platform_api).call do
        output = git_push_heroku_yall
      rescue FailedDeploy => e
        if e.output.match?(/reached the API rate limit/)
          throw(:throttle)
        elsif @allow_failure
          output = e.output
        else
          raise e
        end
      end

      return output
    end

    private def git_push_heroku_yall
      output = `git push #{git_repo} master 2>&1`

      if !$?.success?
        raise FailedDeployError.new(self, "Buildpack: #{@buildpack.inspect}\nRepo: #{git_repo}", output: output)
      end

      releases = platform_api.release.list(name)
      if releases.last["status"] == "failed"
        commit! # An empty commit allows us to deploy again
        raise FailedReleaseError.new(self, "Buildpack: #{@buildpack.inspect}\nRepo: #{git_repo}", output: output)
      end

      return output
    end
  end
end
