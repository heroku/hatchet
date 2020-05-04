# Wraps platform-api and adds API rate limits
#
# Instead of:
#
#     platform_api.pipeline.create(name: @name)
#
# Use:
#
#     api_rate_limit = ApiRateLimit.new(platform_api)
#     api_rate_limit.call.pipeline.create(name: @name)
#
class ApiRateLimit
  def initialize(platform_api)
    @platform_api = platform_api
    @capacity = 1
    @called   = 0
  end


  # Sleeps for progressively longer when api rate limit capacity
  # is lower.
  #
  # Unfortunatley `@platform_api.rate_limit` is an extra API
  # call, so by checking our limit, we also are using our limit 😬
  # to partially mitigate this, only check capacity every 5
  # api calls, or if the current capacity is under 1000
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
