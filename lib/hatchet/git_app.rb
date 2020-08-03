module Hatchet
  # used for deploying a test app to heroku via git
  class GitApp < App
    def git_repo
      "https://git.heroku.com/#{name}.git"
    end

    # Helper class to be used along with the PlatformAPI.rate_throttle interface
    # that expects a response object
    class FakeResponse
      attr_reader :status, :headers

      def initialize(status:, remaining: )
        @status = status

        @headers = {
          "RateLimit-Remaining" => remaining,
          "RateLimit-Multiplier" => 1,
          "Content-Type" => "text/plain".freeze
        }
      end
    end

    def push_without_retry!
      output = ""

      # The `git push heroku` call can fail due to a rate limit, instead of re-writing our own rate throttling
      # we can hijack the existing Platform API rate throttling mechanism by providing it with a fake response
      PlatformAPI.rate_throttle.call do
        remaining = @platform_api.rate_limit.info["remaining"]
        output = git_push_heroku_yall
        FakeResponse.new(status: 200, remaining: remaining)
      rescue FailedDeploy => e
        if e.output.match?(/reached the API rate limit/)
          FakeResponse.new(status: 429, remaining: remaining)
        elsif @allow_failure
          output = e.output
          FakeResponse.new(status: 200, remaining: remaining)
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
        raise FailedReleaseError.new(self, "Buildpack: #{@buildpack.inspect}\nRepo: #{git_repo}", output: output)
      end

      return output
    end
  end
end
