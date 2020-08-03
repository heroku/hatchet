module Hatchet
  # A class for throttling non-http resources
  #
  # Non-http calls can be rate-limited for example shell calls to `heroku run ` and `git push heroku`
  # this class provides an easy interface to leverage the rate throttling behavior baked into `PlatformAPI`
  # for calls things that do not have a real associated web request
  #
  # Example:
  #
  #   output = ""
  #   ShellThrottle.new(platform_api: @platform_api).call
  #     output = `git push heroku main`
  #     throw(:throttle) if output.match?(/reached the API rate limit/)
  #   end
  #   puts output
  #
  # In this example `git push heroku main` will retry and backoff until the output no longer matches `reached the API rate limit`.
  #
  class ShellThrottle
    def initialize(platform_api: )
      @platform_api = platform_api
    end

    def call
      out = nil
      PlatformAPI.rate_throttle.call do
        catch(:throttle) do
          out = yield
          return
        end

        try_again
      end
      return out
    end

    private def success
      FakeResponse.new(status: 200, remaining: remaining)
    end

    private def try_again
      FakeResponse.new(status: 429, remaining: remaining)
    end

    private def remaining
      @platform_api.rate_limit.info["remaining"]
    end


    # Helper class to be used along with the PlatformAPI.rate_throttle interface
    # that expects a response object
    #
    # Example:
    #
    #   FakeResponse.new(status: 200, remaining: 2).status #=> 200
    #   FakeResponse.new(status: 200, remaining: 2).headers["RateLimit-Remaining"] #=> 2
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
  end
end
