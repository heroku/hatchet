module Hatchet
  class FailedTestError < StandardError
    def initialize(app, output)
      msg = "Could not run tests on pipeline id: '#{app.pipeline_id}' (#{app.repo_name}) at path: '#{app.directory}'\n" <<
            " if this was expected add `allow_failure: true` to your hatchet initialization hash.\n" <<
            "output:\n" <<
            "#{output}"
      super(msg)
    end
  end

  class TestRun

    # Hatchet::GitApp.new("rails3_mri_193").run_ci do |test_run|
    #   assert :succeeded, test_run.status
    # end
    #
    # TestRun.new(token: , buildpacks: , test_dir: )
    #
    def initialize(
      token:,
      buildpacks:,
      app:,
      pipeline:,
      api_rate_limit:,
      timeout:        10,
      pause:          5,
      commit_sha:     "sha",
      commit_branch:  "master",
      commit_message: "commit",
      organization:    nil
    )
      @pipeline        = pipeline || "#{Hatchet::APP_PREFIX}#{SecureRandom.hex(5)}"
      @timeout         = timeout
      @pause           = pause
      @organization    = organization
      @token           = token
      @commit_sha      = commit_sha
      @commit_branch   = commit_branch
      @commit_message  = commit_message
      @buildpacks      = Array(buildpacks)
      @app             = app
      @mutex           = Mutex.new
      @status          = false
      @api_rate_limit  = api_rate_limit
    end
    attr_reader :app

    def run_again(&block)
      @mutex.synchronize do
        @status = false
      end

      Hatchet::RETRIES.times.retry do
        create_test_run
      end
      wait!(&block)
    end

    def create_test_run
      @mutex.synchronize do
        raise "Test is already running" if @status
        @status = :building

        body = {
          source_blob_url: source_blob_url,
          pipeline:        @pipeline,
          organization:    @organization,
          commit_sha:      @commit_sha,
          commit_branch:   @commit_branch,
          commit_message:  @commit_message,
        }

        # https://github.com/heroku/api/blob/master/schema/variants/3.ci/platform-api-reference.md#test-run-create
        attributes = excon_request(
          method:  :post,
          path:    "/test-runs",
          version: "3.ci",
          body:    body,
          expects: [201]
        )
        @test_run_id = attributes["id"]
      end
      info
    end

    def info
     # GET /test-runs/{test_run_id}
      response = excon_request(
        method:  :get,
        path:    "/test-runs/#{@test_run_id}",
        version: "3.ci",
        expects: [201, 200]
      )

      @status = response["status"].to_sym
    end

    def status
      @status # :pending, :building, :creating, :succeeded, :failed, :errored
    end

    def output
      test_nodes = excon_request(
        method:  :get,
        path:    "/test-runs/#{@test_run_id}/test-nodes",
        version: "3.ci",
        expects: [200]
      )

      node_output_urls  = []
      test_nodes.each do |test_node|
        node_output_urls << test_node.fetch("setup_stream_url")
        node_output_urls << test_node.fetch("output_stream_url")
      end

      output = String.new
      node_output_urls.each do |url|
        output << get_contents_or_whatever(url)
      end
      output
    end

    def wait!
      Timeout::timeout(@timeout) do
        while true do
          info
          case @status
          when :succeeded
            yield self if block_given?
            return self
          when :failed, :errored
            raise FailedTestError.new(self.app, self.output) unless app.allow_failure?
            yield self if block_given?
            return self
          else
            # keep looping
          end
          sleep @pause
        end
      end
    rescue Timeout::Error
      puts "Timed out status: #{@status}, timeout: #{@timeout}"
      raise FailedTestError.new(self.app, self.output) unless app.allow_failure?
      yield self
      return self
    end

    # Here's where the magic happens folks
    #
    # == Set the buildpack
    #
    # We take the current directory structure and see if it has an `app.json`
    # This is how Heroku CI knows what buildpacks to use to run your tests
    # Hatchet will inject whatever buildpack you pass to it, by default
    # it uses the same buildpack you have specified in your Hatchet constants
    # and uses the same branch your tests are using
    #
    # == Generate source blob url
    #
    # The CI endpoint takes a url that has a `.tgz` file to execute your tests.
    # We pull down the app you're testing against, inject an `app.json` (or modify
    # if it already exists). We the use the heroku "source" api to generate a
    # url that we can put our newly generated `.tgz` file. It also returns a "get"
    # url where those contents can be downloaded. We pass this url back to CI
    #
    def source_blob_url
      @app.in_directory do
        app_json = JSON.parse(File.read("app.json")) if File.exist?("app.json")
        app_json ||= {}
        app_json["environments"]                       ||= {}
        app_json["environments"]["test"]               ||= {}
        app_json["environments"]["test"]["buildpacks"] = @buildpacks.map {|b| { url: b } }
        app_json["environments"]["test"]["env"]        ||= {}
        app_json["environments"]["test"]["env"]        = @app.app_config.merge(app_json["environments"]["test"]["env"]) # copy in explicitly set app config
        app_json["stack"]                              ||= @app.stack if @app.stack && !@app.stack.empty?
        File.open("app.json", "w") {|f| f.write(JSON.generate(app_json)) }

        out = `tar c . | gzip -9 > slug.tgz`
        raise "Tar command failed: #{out}" unless $?.success?

        source_put_url = @app.create_source
        Hatchet::RETRIES.times.retry do
          @api_rate_limit.call
          Excon.put(source_put_url,
                    expects: [200],
                    body:    File.read('slug.tgz'))
        end
      end
      return @app.source_get_url
    end

  private
    def get_contents_or_whatever(url)
      @api_rate_limit.call
      Excon.get(url, read_timeout: @pause).body
    rescue Excon::Error::Timeout
      ""
    end

    def excon_request(options)
      JSON.parse(raw_excon_request(options).body)
    end

    def version
      "3"
    end

    def raw_excon_request(options)
      version = options.delete(:version) || 3
      options[:headers] = {
        "Authorization" => "Bearer #{@token}",
        "Accept"        => "application/vnd.heroku+json; version=#{version}",
        "Content-Type"  => "application/json"
      }.merge(options[:headers] || {})
      options[:body] = JSON.generate(options[:body]) if options[:body]

      Hatchet::RETRIES.times.retry do
        @api_rate_limit.call
        connection = Excon.new("https://api.heroku.com")
        return connection.request(options)
      end
    end
  end
end
