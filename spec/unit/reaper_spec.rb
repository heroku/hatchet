require "spec_helper"

describe "Reaper" do
  it "destroy all" do
    reaper = Hatchet::Reaper.new(api_rate_limit: Object.new, hatchet_app_limit: 1, io: StringIO.new)

    def reaper.get_heroku_apps
      @mock_apps ||= [
        {"name" => "hatchet-t-unfinished", "id" => 2, "maintenance" => false, "created_at" => Time.now.to_s},
        {"name" => "hatchet-t-foo", "id" => 1, "maintenance" => true, "created_at" => Time.now.to_s}
      ]
    end
    def reaper.destroy_with_log(*args); @destroy_with_log_count ||= 0; @destroy_with_log_count += 1; end

    reaper.destroy_all

    expect(reaper.instance_variable_get("@destroy_with_log_count")).to eq(1)
  end

  describe "cycle" do
    it "does not delete anything if no old apps" do
      reaper = Hatchet::Reaper.new(api_rate_limit: Object.new, hatchet_app_limit: 1, io: StringIO.new)

      def reaper.get_heroku_apps
        @called_get_heroku_apps = true

        @mock_apps ||= [{"name" => "hatchet-t-foo", "id" => 1, "maintenance" => true, "created_at" => Time.now.to_s}]
      end
      def reaper.check_get_heroku_apps_called; @called_get_heroku_apps ; end
      def reaper.reap_once; raise "should not be called"; end

      reaper.destroy_older_apps

      expect(reaper.check_get_heroku_apps_called).to be_truthy
    end

    it "deletes an old app that is past TLL" do
      reaper = Hatchet::Reaper.new(api_rate_limit: Object.new, hatchet_app_limit: 0, io: StringIO.new)

      def reaper.get_heroku_apps
        two_days_ago = DateTime.now.new_offset(0) - 2
        @mock_apps ||= [{"name" => "hatchet-t-foo", "id" => 1, "maintenance" => false, "created_at" => two_days_ago.to_s }]
      end
      def reaper.destroy_with_log(name: , id: , reason: )
        @reaper_destroy_called_with = {"name" => name, "id" => id}
      end
      def reaper.destroy_called_with; @reaper_destroy_called_with; end

      reaper.destroy_older_apps

      expect(reaper.destroy_called_with).to eq({"name" => "hatchet-t-foo", "id" => 1})
    end

    it "sleeps, refreshes app list, and tries again when an old app is not past TTL" do
      warning = StringIO.new
      reaper = Hatchet::Reaper.new(
        io: warning,
        initial_sleep: 0,
        api_rate_limit: Object.new,
        hatchet_app_limit: 0,
      )

      def reaper.get_heroku_apps
        now = DateTime.now.new_offset(0)
        @mock_apps ||= [{"name" => "hatchet-t-foo", "id" => 1, "maintenance" => false, "created_at" => now.to_s }]
      end
      def reaper.destroy_with_log(name: , id: , reason: )
        @reaper_destroy_called_with = {"name" => name, "id" => id}
      end
      def reaper.destroy_called_with; @reaper_destroy_called_with; end
      def reaper.sleep(val)
        @_slept_for = val
      end

      def reaper.get_slept_for_val; @_slept_for; end

      reaper.destroy_older_apps
      reaper.sleep_if_over_limit(reason: "test")

      expect(reaper.get_slept_for_val).to eq(0)
      expect(reaper.destroy_called_with).to eq(nil)

      expect(warning.string).to include("WARNING: Hatchet app limit reached (1/0)")
    end
  end

  describe "app age" do
    it "calculates young apps" do
      time_now = DateTime.parse("2020-07-28T14:40:00Z")
      age = Hatchet::Reaper::AppAge.new(created_at: time_now, time_now: time_now, ttl_minutes: 1)
      expect(age.in_minutes).to eq(0.0)
      expect(age.too_young_to_die?).to be_truthy
      expect(age.can_delete?).to be_falsey
      expect(age.sleep_for_ttl).to eq(60)
    end

    it "calculates old apps" do
      time_now = DateTime.parse("2020-07-28T14:40:00Z")
      created_at = time_now - 2
      age = Hatchet::Reaper::AppAge.new(created_at: created_at, time_now: time_now, ttl_minutes: 1)
      expect(age.in_minutes).to eq(2880.0)
      expect(age.too_young_to_die?).to be_falsey
      expect(age.can_delete?).to be_truthy
      expect(age.sleep_for_ttl).to eq(0)
    end
  end

  describe "reaper throttle" do
    it "increments and decrements based on min_sleep" do
      reaper_throttle = Hatchet::Reaper::ReaperThrottle.new(initial_sleep: 2)
      reaper_throttle.call(max_sleep: 5) do |sleep_for|
        expect(sleep_for).to eq(2)
      end
      reaper_throttle.call(max_sleep: 5) do |sleep_for|
        expect(sleep_for).to eq(4)
      end
      reaper_throttle.call(max_sleep: 5) do |sleep_for|
        expect(sleep_for).to eq(5)
      end
      # The throttle is now reset since it hit the min_sleep value

      reaper_throttle.call(max_sleep: 5) do |sleep_for|
        expect(sleep_for).to eq(2)
      end
    end
  end
end
