# Legacy class
#
# Not needed since rate throttling went directly into the platform-api gem.
# This class is effectively now a no-op
#
# It's being left in as it's interface was public and it's hard-ish to
# deprecate/remove. Since it's so small there's not much value in removal
# so it's probably fine to keep around for quite some time.
class ApiRateLimit
  def initialize(platform_api)
    @platform_api = platform_api
    @capacity = 1
    @called   = 0
  end

  def call
    # @called += 1

    # if @called > 5 || @capacity < 1000
    #   @called = 0
    #   @capacity = @platform_api.rate_limit.info["remaining"]
    # end

    # sleep_time = (60/@capacity) if @capacity > 0.1 # no divide by zero
    # sleep(sleep_time || 60)

    return @platform_api
  end
end
