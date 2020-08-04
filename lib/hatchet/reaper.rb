require 'tmpdir'

module Hatchet
  # This class lazilly deletes hatchet apps
  #
  # When the reaper is called, it will check if the system has too many apps (Bassed off of HATCHET_APP_LIMIT), if so it will attempt
  # to delete an app to free up capacity. The goal of lazilly deleting apps is to temporarilly keep
  # apps around for debugging if they fail.
  #
  # When App#teardown! is called on an app it is marked as being in a "finished" state by turning
  # on maintenance mode. The reaper will delete these in order (oldest first).
  #
  # If no apps are marked as being "finished" then the reaper will check to see if the oldest app
  # has been alive for a long enough period for it's tests to finish (configured by HATCHET_ALIVE_TTL_MINUTES env var).
  # If the "unfinished" app has been alive that long it will be deleted. If not, the system will sleep for a period of time
  # in an attempt to allow other apps to move to be "finished".
  #
  # This class only limits and the number of "hatchet" apps on the system. Prevously there was a maximum of 100 apps on a
  # Heroku account. Now a user can belong to multiple orgs and the total number of apps they have access to is no longer
  # fixed at 100. Instead of hard coding a maximum limit, this failure mode is handled by forcing deletion of
  # an app when app creation fails. In the future we may find a better way of detecting this failure mode
  #
  # Notes:
  #
  # - The class uses a file mutex so that multiple processes on the same machine do not attempt to run the
  #   reaper at the same time.
  # - AlreadyDeletedError will be raised if an app has already been deleted (possibly by another test run on
  #   another machine). When this happens, the system will automatically attempt to reap another app.
  class Reaper
    class AlreadyDeletedError < StandardError; end

    HATCHET_APP_LIMIT = Integer(ENV["HATCHET_APP_LIMIT"] || 20)  # the number of apps hatchet keeps around
    DEFAULT_REGEX = /^#{Regexp.escape(Hatchet::APP_PREFIX)}[a-f0-9]+/

    attr_accessor :io, :hatchet_app_limit

    def initialize(api_rate_limit: , regex: DEFAULT_REGEX, io: STDOUT, hatchet_app_limit:  HATCHET_APP_LIMIT, initial_sleep: 10)
      @api_rate_limit = api_rate_limit
      @regex = regex
      @io = io
      @finished_hatchet_apps = []
      @unfinished_hatchet_apps = []
      @app_count = 0
      @hatchet_app_limit = hatchet_app_limit
      @reaper_throttle = ReaperThrottle.new(initial_sleep: initial_sleep)
    end

    def cycle(app_exception_message: false)
      # Protect against parallel deletion of the same app on the same system
      mutex_file = File.open("#{Dir.tmpdir()}/hatchet_reaper_mutex", File::CREAT)
      mutex_file.flock(File::LOCK_EX)

      refresh_app_list if @finished_hatchet_apps.empty?

      # To be safe try to delete an app even if we're not over the limit
      # since the exception may have been caused by going over the maximum account limit
      if app_exception_message
          io.puts <<~EOM
            WARNING: Running reaper due to exception on app
                     #{stats_string}
                     Exception: #{app_exception_message}
          EOM
        reap_once
      end

      while over_limit?
        reap_once
      end
    ensure
      mutex_file.close
    end

    def stats_string
      "total_app_count: #{@app_count}, hatchet_app_count: #{hatchet_app_count}/#{HATCHET_APP_LIMIT}, finished: #{@finished_hatchet_apps.length}, unfinished: #{@unfinished_hatchet_apps.length}"
    end

    def over_limit?
      hatchet_app_count > hatchet_app_limit
    end

    # No guardrails, will delete all apps that match the hatchet namespace
    def destroy_all
      get_apps

      (@finished_hatchet_apps + @unfinished_hatchet_apps).each do |app|
        begin
          destroy_with_log(name: app["name"], id: app["id"])
        rescue AlreadyDeletedError
          # Ignore, keep going
        end
      end
    end

    private def reap_once
      refresh_app_list if @finished_hatchet_apps.empty?

      if (app = @finished_hatchet_apps.pop)
        destroy_with_log(name: app["name"], id: app["id"])
      elsif (app = @unfinished_hatchet_apps.pop)
        destroy_if_old_enough(app)
      end
    rescue AlreadyDeletedError
      retry
    end

    # Checks to see if the given app is older than the HATCHET_ALIVE_TTL_MINUTES
    # if so, then the app is deleted, otherwise the reaper sleeps for a period of time after which
    # It can try again to delete another app. The hope is that some apps will be marked as finished
    # in that time
    private def destroy_if_old_enough(app)
      age = AppAge.new(
        created_at: app["created_at"],
        ttl_minutes: ENV.fetch("HATCHET_ALIVE_TTL_MINUTES", "7").to_i
      )
      if age.can_delete?
        io.puts "WARNING: Destroying an app without maintenance mode on, app: #{app["name"]}, app_age: #{age.in_minutes} minutes"

        destroy_with_log(name: app["name"], id: app["id"])
      else
        # We're not going to delete it yet, so put it back
        @unfinished_hatchet_apps << app

        # Sleep, try again later
        @reaper_throttle.call(max_sleep: age.sleep_for_ttl) do |sleep_for|
          io.puts <<~EOM
            WARNING: Attempting to destroy an app without maintenance mode on, but it is not old enough. app: #{app["name"]}, app_age: #{age.in_minutes} minutes
                     This can happen if App#teardown! is not called on an application, which will leave it in an 'unfinished' state
                     This can also happen if you're trying to run more tests concurrently than your currently set value for HATCHET_APP_COUNT
                     Sleeping: #{sleep_for} seconds before trying to find another app to reap"
                     #{stats_string}, HATCHET_ALIVE_TTL_MINUTES=#{age.ttl_minutes}
          EOM

          sleep(sleep_for)
        end
      end
    end

    private def get_heroku_apps
      @api_rate_limit.call.app.list
    end

    private def refresh_app_list
      apps = get_heroku_apps.
        map {|app| app["created_at"] = DateTime.parse(app["created_at"].to_s); app }.
        sort_by { |app| app["created_at"] }.
        reverse # Ascending order, oldest is last

      @app_count = apps.length

      @finished_hatchet_apps.clear
      @unfinished_hatchet_apps.clear
      apps.each do |app|
        next unless app["name"].match(@regex)

        if app["maintenance"]
          @finished_hatchet_apps << app
        else
          @unfinished_hatchet_apps << app
        end
      end
    end

    private def destroy_with_log(name:, id:)
      message = "Destroying #{name.inspect}: #{id}, #{stats_string}"

      @api_rate_limit.call.app.delete(id)

      io.puts message
    rescue Excon::Error::NotFound => e
      body = e.response.body
      request_id = e.response.headers["Request-Id"]
      if body =~ /Couldn\'t find that app./
        io.puts "Duplicate destoy attempted #{name.inspect}: #{id}, status: 404, request_id: #{request_id}"
        raise AlreadyDeletedError.new
      else
        raise e
      end
    rescue Excon::Error::Forbidden => e
      request_id = e.response.headers["Request-Id"]
      io.puts "Duplicate destoy attempted #{name.inspect}: #{id}, status: 403, request_id: #{request_id}"
      raise AlreadyDeletedError.new
    end

    private def hatchet_app_count
      @finished_hatchet_apps.length + @unfinished_hatchet_apps.length
    end
  end
end

require_relative "reaper/app_age"
require_relative "reaper/reaper_throttle"
