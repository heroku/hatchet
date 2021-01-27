require "spec_helper"

describe "ShellThrottle" do
  before(:each) do
    throttle = PlatformAPI.rate_throttle
    def throttle.sleep(value)
      # No sleep, faster tests
    end
  end

  after(:each) do
    throttle = PlatformAPI.rate_throttle
    def throttle.sleep(value)
      super # Unstub
    end
  end

  describe "class unit test" do
    before(:all) do
      @platform_api = Hatchet::Runner.new("default_ruby").platform_api
    end

    it "throttles when throw is called" do
      @count = 0
      Hatchet::ShellThrottle.new(platform_api: @platform_api).call do
        @count += 1
        if @count >= 2
          # No throttle
        else
          throw(:throttle)
        end
      end
      expect(@count).to eq(2)
    end

    it "does not throttle when throw is NOT called" do
      @count = 0
      Hatchet::ShellThrottle.new(platform_api: @platform_api).call do
        @count += 1
      end
      expect(@count).to eq(1)
    end
  end

  describe "git push throttle" do
    it "rate throttles `git push` with output variation 1" do
      app = Hatchet::GitApp.new("default_ruby")
      def app.git_push_heroku_yall
        @_git_push_heroku_yall_call_count ||= 0
        @_git_push_heroku_yall_call_count += 1
        if @_git_push_heroku_yall_call_count >= 2
          "Success"
        else
          raise Hatchet::App::FailedDeployError.new(
            self,
            "message",
            output: "Your account reached the API rate limit Please wait a few minutes before making new requests"
          )
        end
      end

      def app.sleep_called?; @sleep_called; end
      def app.what_is_git_push_heroku_yall_call_count; @_git_push_heroku_yall_call_count; end

      app.push_without_retry!

      expect(app.what_is_git_push_heroku_yall_call_count).to be(2)
    end

    it "rate throttles `git push` with output variation 2" do
      app = Hatchet::GitApp.new("default_ruby")
      def app.git_push_heroku_yall
        @_git_push_heroku_yall_call_count ||= 0
        @_git_push_heroku_yall_call_count += 1
        if @_git_push_heroku_yall_call_count >= 2
          "Success"
        else
          raise Hatchet::App::FailedDeployError.new(
            self,
            "message",
            output: "RPC failed; HTTP 429 curl 22 The requested URL returned error: 429 Too Many Requests"
          )
        end
      end

      def app.sleep_called?; @sleep_called; end
      def app.what_is_git_push_heroku_yall_call_count; @_git_push_heroku_yall_call_count; end

      app.push_without_retry!

      expect(app.what_is_git_push_heroku_yall_call_count).to be(2)
    end

    it "rate throttles `git push` with output variation 3" do
      app = Hatchet::GitApp.new("default_ruby")
      def app.git_push_heroku_yall
        @_git_push_heroku_yall_call_count ||= 0
        @_git_push_heroku_yall_call_count += 1
        if @_git_push_heroku_yall_call_count >= 2
          "Success"
        else
          raise Hatchet::App::FailedDeployError.new(
            self,
            "message",
            output: "error: RPC failed; HTTP 429 curl 22 The requested URL returned error: 429"
          )
        end
      end

      def app.sleep_called?; @sleep_called; end
      def app.what_is_git_push_heroku_yall_call_count; @_git_push_heroku_yall_call_count; end

      app.push_without_retry!

      expect(app.what_is_git_push_heroku_yall_call_count).to be(2)
    end

    it "rate throttles `git push` with output variation 4" do
      app = Hatchet::GitApp.new("default_ruby")
      def app.git_push_heroku_yall
        @_git_push_heroku_yall_call_count ||= 0
        @_git_push_heroku_yall_call_count += 1
        if @_git_push_heroku_yall_call_count >= 2
          "Success"
        else
          raise Hatchet::App::FailedDeployError.new(
            self,
            "message",
            output: "error: RPC failed; result=22, HTTP code = 429"
          )
        end
      end

      def app.sleep_called?; @sleep_called; end
      def app.what_is_git_push_heroku_yall_call_count; @_git_push_heroku_yall_call_count; end

      app.push_without_retry!

      expect(app.what_is_git_push_heroku_yall_call_count).to be(2)
    end
  end
end
