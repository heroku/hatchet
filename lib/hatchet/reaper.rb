module Hatchet
  # Hatchet apps are useful after the tests run for debugging purposes
  # the reaper is designed to allow the most recent apps to stay alive
  # while keeping the total number of apps under the global Heroku limit.
  # Any time you're worried about hitting the limit call @reaper.cycle
  #
  class Reaper
    HEROKU_APP_LIMIT = Integer(ENV["HEROKU_APP_LIMIT"]  || 100) # the number of apps heroku allows you to keep
    HATCHET_APP_LIMT = Integer(ENV["HATCHET_APP_LIMIT"] || 20)  # the number of apps hatchet keeps around
    DEFAULT_REGEX = /^hatchet-t-/
    attr_accessor :apps


    def initialize(platform_api:, regex: DEFAULT_REGEX)
      @platform_api = platform_api
      @regex        = regex
    end

    # Ascending order, oldest is last
    def get_apps
      apps          = @platform_api.app.list.sort_by { |app| DateTime.parse(app["created_at"]) }.reverse
      @app_count    = apps.count
      @hatchet_apps = apps.select {|app| app["name"].match(@regex) }
    end

    def cycle
      get_apps
      if over_limit?
        if @hatchet_apps.count > 1
          destroy_oldest
          cycle
        else
          puts "Warning: Reached Heroku app limit of #{HEROKU_APP_LIMIT}."
        end
      else
        # do nothing
      end

    # If the app is already deleted an exception
    # will be raised, if the app cannot be found
    # assume it is already deleted and try again
    rescue Excon::Error::NotFound => e
      body = e.response.body
      if body =~ /Couldn\'t find that app./
        puts "#{@message}, but looks like it was already deleted"
        retry
      end
      raise e
    end

    def destroy_oldest
      oldest = @hatchet_apps.pop
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
      @platform_api.app.delete(id)
    end

    private

    def over_limit?
      @app_count > HEROKU_APP_LIMIT || @hatchet_apps.count > HATCHET_APP_LIMT
    end
  end
end
