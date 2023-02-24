require 'tmpdir'

module Hatchet
  # Delete apps
  #
  # Delete a single app:
  #
  #   @reaper.destroy_with_log(id: id, name: name, reason: "console")
  #
  # Clear out all apps older than HATCHET_ALIVE_TTL_MINUTES:
  #
  #   @reaper.destroy_older_apps
  #
  # If you need to clear up space or wait for space to be cleared
  # up then:
  #
  #   @reaper.clean_old_or_sleep
  #
  #
  # Notes:
  #
  # - The class uses a file mutex so that multiple processes on the same machine do not attempt to run the
  #   reaper at the same time.
  class Reaper
    class AlreadyDeletedError < StandardError; end

    HATCHET_APP_LIMIT = Integer(ENV["HATCHET_APP_LIMIT"] || 20)  # the number of apps hatchet keeps around
    DEFAULT_REGEX = /^#{Regexp.escape(Hatchet::APP_PREFIX)}[a-f0-9]+/
    TTL_MINUTES = ENV.fetch("HATCHET_ALIVE_TTL_MINUTES", "7").to_i

    attr_accessor :io, :hatchet_app_limit

    def initialize(api_rate_limit: , regex: DEFAULT_REGEX, io: STDOUT, hatchet_app_limit:  HATCHET_APP_LIMIT, initial_sleep: 10)
      @io = io
      @apps = []
      @regex = regex
      @limit = hatchet_app_limit
      @api_rate_limit = api_rate_limit
      @reaper_throttle = ReaperThrottle.new(initial_sleep: initial_sleep)
    end

    # Called when we need an app, but are over limit or
    # if an exception has occured that was possibly triggered
    # by apps being over limit
    def clean_old_or_sleep
      # Protect against parallel deletion of the same app on the same system
      mutex_file = File.open("#{Dir.tmpdir()}/hatchet_reaper_mutex", File::CREAT)
      mutex_file.flock(File::LOCK_EX)

      destroy_older_apps(force_refresh: true)

      if @apps.length > @limit
        age = AppAge.new(created_at: @apps.last["created_at"], ttl_minutes: TTL_MINUTES)
        @reaper_throttle.call(max_sleep: age.sleep_for_ttl) do |sleep_for|
          io.puts <<-EOM.strip_heredoc
            WARNING: Hatchet app limit reached (#{@apps.length}/#{@limit})
                     All known apps are younger than #{TTL_MINUTES} minutes
          EOM

          sleep(sleep_for)
        end
      end
    ensure
      mutex_file.close
    end

    # Destroys apps that are older than the given argument (expecting integer minutes)
    def destroy_older_apps(minutes: TTL_MINUTES, force_refresh: @apps.empty?)
      refresh_app_list if force_refresh

      @apps.each do |app|
        age = AppAge.new(created_at: app["created_at"], ttl_minutes: minutes)
        if age.can_delete?
          destroy_with_log(
            name: app["name"],
            id: app["id"],
            reason: "app age (#{age.in_minutes}m) is older than #{minutes}m"
          )
        end
      rescue AlreadyDeletedError
        # Ignore, keep going
      end
    end

    # No guardrails, will delete all apps that match the hatchet namespace
    def destroy_all(force_refresh: @apps.empty?)
      refresh_app_list if force_refresh

      @apps.each do |app|
        begin
          destroy_with_log(name: app["name"], id: app["id"], reason: "destroy all")
        rescue AlreadyDeletedError
          # Ignore, keep going
        end
      end
    end

    private def get_heroku_apps
      @api_rate_limit.call.app.list
    end

    private def refresh_app_list
      @apps = get_heroku_apps.
        filter {|app| app["name"].match(@regex) }.
        map {|app| app["created_at"] = DateTime.parse(app["created_at"].to_s); app }.
        sort_by { |app| app["created_at"] }.
        reverse # Ascending order, oldest is last
    end

    def destroy_with_log(name:, id:, reason: )
      message = "Destroying #{name.inspect}: #{id}, (#{@apps.length}/#{@limit}) reason: #{reason}"

      @api_rate_limit.call.app.delete(id)

      io.puts message
    rescue Excon::Error::NotFound => e
      body = e.response.body
      request_id = e.response.headers["Request-Id"]
      if body =~ /Couldn\'t find that app./
        io.puts "Duplicate destroy attempted #{name.inspect}: #{id}, status: 404, request_id: #{request_id}"
        raise AlreadyDeletedError.new
      else
        raise e
      end
    rescue Excon::Error::Forbidden => e
      request_id = e.response.headers["Request-Id"]
      io.puts "Duplicate destroy attempted #{name.inspect}: #{id}, status: 403, request_id: #{request_id}"
      raise AlreadyDeletedError.new
    end
  end
end

require_relative "reaper/app_age"
require_relative "reaper/reaper_throttle"
