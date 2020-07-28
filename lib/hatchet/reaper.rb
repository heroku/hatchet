require 'tmpdir'

module Hatchet
  # Hatchet apps are useful after the tests run for debugging purposes
  # the reaper is designed to allow the most recent apps to stay alive
  # while keeping the total number of apps under the global Heroku limit.
  # Any time you're worried about hitting the limit call @reaper.cycle
  #
  class Reaper
    HEROKU_APP_LIMIT = Integer(ENV["HEROKU_APP_LIMIT"]  || 100) # the number of apps heroku allows you to keep
    HATCHET_APP_LIMT = Integer(ENV["HATCHET_APP_LIMIT"] || 20)  # the number of apps hatchet keeps around
    DEFAULT_REGEX = /^#{Regexp.escape(Hatchet::APP_PREFIX)}[a-f0-9]+/
    MINUTES_TO_SECONDS = 60
    SECONDS_IN_A_DAY = 24 * 60 * 60

    attr_accessor :apps

    def initialize(api_rate_limit: , regex: DEFAULT_REGEX)
      @api_rate_limit = api_rate_limit
      @regex        = regex
      @hatchet_apps = []
    end

    # Ascending order, oldest is last
    def get_apps
      apps          = @api_rate_limit.call.app.list.sort_by { |app| DateTime.parse(app["created_at"]) }.reverse
      @app_count    = apps.count
      @hatchet_apps = apps.select {|app| app["name"].match(@regex) }
    end

    def cycle
      # we don't want multiple Hatchet processes (e.g. when using rspec-parallel) to delete apps at the same time
      # this could otherwise result in race conditions in API causing errors other than 404s, making tests fail
      mutex = File.open("#{Dir.tmpdir()}/hatchet_reaper_mutex", File::CREAT)
      mutex.flock(File::LOCK_EX)

      # update list of apps once
      get_apps

      return unless over_limit?

      while over_limit?
        if @hatchet_apps.count > 1
          # remove our own apps until we are below limit
          destroy_oldest
        else
          puts "Warning: Reached Heroku app limit: #{@app_count}/#{HEROKU_APP_LIMIT}, hatchet_app_count: #{@hatchet_apps.count}/#{HATCHET_APP_LIMIT}"
          break
        end
      end

    # If the app is already deleted an exception
    # will be raised, if the app cannot be found
    # assume it is already deleted and try again
    rescue Excon::Error::NotFound => e
      body = e.response.body
      if body =~ /Couldn\'t find that app./
        puts "#{@message}, but looks like it was already deleted"
        mutex.close # ensure only gets called on block exit and not on `retry`
        retry
      end
      raise e
    ensure
      # don't forget to close the mutex; this also releases our lock
      mutex.close
    end

    # If you have too many concurrent jobs running you might delete an app that is currently being used
    # this method enforces a minimum time to live, defaulted to 7 minutes
    #
    # If hatchet runs out of apps and the oldest app is younger than 7 minutes old, then it will
    # sleep until the app can be destroyed.
    def ensure_app_minimum_ttl(oldest_created_at, time_now: DateTime.now.new_offset(0), jitter_multiplier: rand(1.0..1.05), io: STDOUT)
      # Comparing DateTime objects returns a fraction of a day, need to convert it into seconds
      #   https://ruby-doc.org/stdlib-2.6.1/libdoc/date/rdoc/Date.html#method-i-2D
      time_diff = time_now - DateTime.parse(oldest_created_at)
      seconds_since_oldest_created = (time_diff * SECONDS_IN_A_DAY).to_i

      minimum_minutes = Integer(ENV.fetch("HATCHET_MINIMUM_TTL_MINUTES", "7"))
      minimum_seconds = minimum_minutes * MINUTES_TO_SECONDS

      if seconds_since_oldest_created > minimum_seconds
        # do nothing, App is old enough
      else
        time_diff =  minimum_seconds - seconds_since_oldest_created
        io.puts "Warning: Attempting to destroy an app, but cannot due to minimum time to live. sleeping: #{time_diff}"
        io.puts "         oldest app created #{seconds_since_oldest_created / 60.0} minutes ago, total app count: #{@app_count}, hatchet app count: #{@hatchet_apps.count}"
        io.puts "         HATCHET_MINIMUM_TTL_MINUTES=#{minimum_minutes}"

        sleep(time_diff * jitter_multiplier)
      end
    end

    def destroy_oldest
      oldest = @hatchet_apps.pop

      ensure_app_minimum_ttl(oldest["created_at"])

      destroy_by_id(name: oldest["name"], id: oldest["id"], details: "Hatchet app limit: #{HATCHET_APP_LIMT}")
    end

    def destroy_all
      get_apps
      @hatchet_apps.each do |app|
        destroy_by_id(name: app["name"], id: app["id"])
      end
    end

    def destroy_by_id(name:, id:, details: "")
      @message = "Destroying #{name.inspect}: #{id}. #{details}"
      puts @message
      @api_rate_limit.call.app.delete(id)
    end

    private

    def over_limit?
      @app_count > HEROKU_APP_LIMIT || @hatchet_apps.count > HATCHET_APP_LIMT
    end
  end
end
