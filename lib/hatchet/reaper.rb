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


    def initialize(heroku, regex = DEFAULT_REGEX)
      @heroku = heroku
      @regex  = regex
    end

    # Ascending order, oldest is last
    def get_apps
      @apps         = @heroku.get_apps.body.sort_by {|app| DateTime.parse(app["created_at"]) }.reverse
      @hatchet_apps = @apps.select {|app| app["name"].match(@regex) }
      @apps
    end

    def cycle(apps = get_apps)
      if over_limit?
        destroy_oldest
        cycle
      else
        # do nothing
      end
    end

    def destroy_oldest
      oldest_name = @hatchet_apps.pop["name"]
      destroy_by_name(oldest_name, "Hatchet app limit: #{HATCHET_APP_LIMT}")
    rescue Heroku::API::Errors::NotFound
      # app already deleted, cycle will catch if there's still too many
    end

    def destroy_all
      get_apps
      @hatchet_apps.each do |app|
        destroy_by_name(app["name"])
      end
    end

    def destroy_by_name(name, details="")
      puts "Destroying #{name.inspect}. #{details}"
      @heroku.delete_app(name)
    end

    private

    def over_limit?
      @apps.count > HEROKU_APP_LIMIT || @hatchet_apps.count > HATCHET_APP_LIMT
    end
  end
end
