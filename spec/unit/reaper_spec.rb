require "spec_helper"

describe "Reaper" do
  it "Calculates minimum time to sleep" do
    reaper = Hatchet::Reaper.new(api_rate_limit: -> (){} )
    def reaper.sleep(value); @sleep_value = value; end
    def reaper.what_is_sleep_value; @sleep_value; end

    time_string = "2020-07-28T14:40:00Z"
    time_now = DateTime.parse(time_string)
    reaper.ensure_app_minimum_ttl(time_string, time_now: time_now, jitter_multiplier: 1, io: StringIO.new)

    expect(reaper.what_is_sleep_value).to eq(7 * 60)
  end

  it "does not sleep if app is old enough" do
    reaper = Hatchet::Reaper.new(api_rate_limit: -> (){} )
    def reaper.sleep(value); @sleep_value = value; end
    def reaper.what_is_sleep_value; @sleep_value; end

    time_now = DateTime.parse("2020-07-28T14:47:01Z")
    reaper.ensure_app_minimum_ttl("2020-07-28T14:40:00Z", time_now: time_now, jitter_multiplier: 1, io: StringIO.new)

    expect(reaper.what_is_sleep_value).to be_nil
  end
end
