require "spec_helper"

describe "ShellThrottle" do
  it "throttles when throw is called" do
    platform_api = Hatchet::Runner.new("default_ruby").platform_api

    @count = 0
    Hatchet::ShellThrottle.new(platform_api: platform_api).call do
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
    platform_api = Hatchet::Runner.new("default_ruby").platform_api

    @count = 0
    Hatchet::ShellThrottle.new(platform_api: platform_api).call do
      @count += 1
    end
    expect(@count).to eq(1)
  end
end
