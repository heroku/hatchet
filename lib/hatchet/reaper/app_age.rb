module Hatchet
  class Reaper
    # Class for figuring out how old a given time is relative to another time
    #
    # Expects inputs as a DateTime instance
    #
    # Example:
    #
    #   time_now = DateTime.parse("2020-07-28T14:40:00Z")
    #   age = AppAge.new(created_at: DateTIme.parse("2020-07-28T14:40:00Z"), time_now: time_now, ttl_minutes: 1)
    #   age.in_minutes => 0.0
    #   age.too_young_to_die? # => true
    #   age.can_delete? # => false
    #   age.sleep_for_ttl #=> 60
    class AppAge
      SECONDS_IN_A_DAY = 24 * 60 * 60

      attr_reader :ttl_minutes

      def initialize(created_at:, ttl_minutes:, time_now: DateTime.now.new_offset(0))
        @seconds_ago = date_time_diff_in_seconds(time_now, created_at)
        @ttl_minutes = ttl_minutes
        @ttl_seconds = ttl_minutes * 60
      end

      def date_time_diff_in_seconds(now, whence)
        (now - whence) * SECONDS_IN_A_DAY
      end

      def too_young_to_die?
        !can_delete?
      end

      def can_delete?
        @seconds_ago > @ttl_seconds
      end

      def sleep_for_ttl
        return 0 if can_delete?

        @ttl_seconds - @seconds_ago
      end

      def in_minutes
        (@seconds_ago / 60.0).round(2)
      end
    end
  end
end
