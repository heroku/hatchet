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

    # Protect against parallel deletion on the same machine
    # via concurrent processes
    #
    # Does not protect against distributed systems on different
    # machines trying to delete the same applications
    MUTEX_FILE = File.open(File.join(Dir.tmpdir(), "hatchet_reaper_mutex"), File::CREAT)

    attr_accessor :io, :hatchet_app_limit

    def initialize(api_rate_limit: , regex: DEFAULT_REGEX, io: STDOUT, hatchet_app_limit:  HATCHET_APP_LIMIT, initial_sleep: 10)
      @io = io
      @apps = []
      @regex = regex
      @limit = hatchet_app_limit
      @api_rate_limit = api_rate_limit
      @reaper_throttle = ReaperThrottle.new(initial_sleep: initial_sleep)
    end

    def sleep_if_over_limit(reason: )
      if @apps.length >= @limit
        age = AppAge.new(created_at: @apps.last["created_at"], ttl_minutes: TTL_MINUTES)
        @reaper_throttle.call(max_sleep: age.sleep_for_ttl) do |sleep_for|
          io.puts <<-EOM.strip_heredoc
            WARNING: Hatchet app limit reached (#{@apps.length}/#{@limit})
            All known apps are younger than #{TTL_MINUTES} minutes.
            Sleeping (#{sleep_for}s)

            Reason: #{reason}
          EOM

          sleep(sleep_for)
        end
      end
    end

    # Destroys apps that are older than the given argument (expecting integer minutes)
    #
    # This method might be running concurrently on multiple processes or multiple
    # machines.
    #
    # When a duplicate destroy is detected we can move forward with a conflict strategy:
    #
    # - `:refresh_api_and_continue`: Sleep to see if another process will clean up everything for
    #   us and then re-populate apps from the API and continue.
    # - `:stop_if_under_limit`: Sleep to allow other processes to continue. Then if apps list
    #   is under the limit, assume someone else is already cleaning up for us and that we're
    #   good to move ahead to try to create an app. Otherwise if we're at or
    #   over the limit sleep, refresh the app list, and continue attempting to delete apps.
    def destroy_older_apps(minutes: TTL_MINUTES, force_refresh: @apps.empty?, on_conflict: :refresh_api_and_continue)
      MUTEX_FILE.flock(File::LOCK_EX)

      refresh_app_list if force_refresh

      while app = @apps.pop
        age = AppAge.new(created_at: app["created_at"], ttl_minutes: minutes)
        if !age.can_delete?
          @apps.push(app)
          break
        else
          begin
            destroy_with_log(
              id: app["id"],
              name: app["name"],
              reason: "app age (#{age.in_minutes}m) is older than #{minutes}m"
            )
          rescue AlreadyDeletedError => e
            if handle_conflict(
              strategy: on_conflict,
              conflict_message: e.message,
            ) == :stop
              break
            end
          end
        end
      end
    ensure
      MUTEX_FILE.flock(File::LOCK_UN)
    end

    # No guardrails, will delete all apps that match the hatchet namespace
    def destroy_all(force_refresh: @apps.empty?)
      MUTEX_FILE.flock(File::LOCK_EX)

      refresh_app_list if force_refresh

      while app = @apps.pop
        begin
          destroy_with_log(name: app["name"], id: app["id"], reason: "destroy all")
        rescue AlreadyDeletedError => e
          handle_conflict(
            conflict_message: e.message,
            strategy: :refresh_api_and_continue
          )
        end
      end
    ensure
      MUTEX_FILE.flock(File::LOCK_UN)
    end

    # Will sleep with backoff and emit a warning message
    # returns :continue or :stop symbols
    # :stop indicates execution should stop
    private def handle_conflict(conflict_message:, strategy:)
      message = String.new(<<-EOM.strip_heredoc)
        WARNING: Possible race condition detected: #{conflict_message}
        Hatchet app limit (#{@apps.length}/#{@limit}), using strategy #{strategy}
      EOM

      conflict_state = if :refresh_api_and_continue ==  strategy
        message << "\nSleeping, refreshing app list, and continuing."
        :continue
      elsif :stop_if_under_limit == strategy && @apps.length >= @limit
        message << "\nSleeping, refreshing app list, and continuing. Not under limit."
        :continue
      elsif :stop_if_under_limit == strategy
        message << "\nHalting deletion of older apps. Under limit."
        :stop
      else
        raise "No such strategy: #{strategy}, plese use :stop_if_under_limit or :refresh_api_and_continue"
      end

      @reaper_throttle.call(max_sleep: TTL_MINUTES) do |sleep_for|
        io.puts <<-EOM.strip_heredoc
          #{message}
          Sleeping (#{sleep_for}s)
        EOM

        sleep(sleep_for)
      end

      case conflict_state
      when :continue
        refresh_app_list
      when :stop
      else
        raise "Unknown state #{conflict_state}"
      end

      conflict_state
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
        message = "Duplicate destroy attempted #{name.inspect}: #{id}, status: 404, request_id: #{request_id}"
        raise AlreadyDeletedError.new(message)
      else
        raise e
      end
    rescue Excon::Error::Forbidden => e
      request_id = e.response.headers["Request-Id"]
      message = "Duplicate destroy attempted #{name.inspect}: #{id}, status: 403, request_id: #{request_id}"
      raise AlreadyDeletedError.new(message)
    end
  end
end

require_relative "reaper/app_age"
require_relative "reaper/reaper_throttle"
