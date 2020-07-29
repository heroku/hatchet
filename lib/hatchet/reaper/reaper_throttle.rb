module Hatchet
  class Reaper
    # This class retains and increments a sleep value between executions
    #
    # Every time we pause, we increase the duration of the pause 2x. If we
    # do not sleep for long enough then we will burn API requests that we don't need to make.
    #
    # To help prevent sleeping for too long, the reaper will sleep for a maximum amount of time
    # equal to the age_sleep_for_ttl. If that happens, it's likely a fairly large value and the
    # internal incremental value can be reset
    #
    # Example:
    #
    #   reaper_throttle = ReaperThrottle.new(initial_sleep: 2)
    #   reaper_throttle.call(min_sleep: 5) do |sleep_for|
    #     puts sleep_for # => 2
    #   end
    #   reaper_throttle.call(min_sleep: 5) do |sleep_for|
    #     puts sleep_for # => 4
    #   end
    #   reaper_throttle.call(min_sleep: 5) do |sleep_for|
    #     puts sleep_for # => 5
    #   end
    #
    #   # The throttle is now reset since it hit the min_sleep value
    #
    #   reaper_throttle.call(min_sleep: 5) do |sleep_for|
    #     puts sleep_for # => 2
    #   end
    class ReaperThrottle
      def initialize(initial_sleep: )
        @initial_sleep = initial_sleep
        @sleep_for = @initial_sleep
      end

      def call(min_sleep: )
        raise "Must call with a block" unless block_given?

        sleep_for = [@sleep_for, min_sleep].min

        yield sleep_for

        if sleep_for < @sleep_for
          reset!
        else
          @sleep_for *= 2
        end
      end

      def reset!
        @sleep_for = @initial_sleep
      end
    end
  end
end
