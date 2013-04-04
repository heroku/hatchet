require 'json'
require 'stringio'

module Hatchet
  class AnvilApp < App

    def initialize(directory, options = {})
      @buildpack   = options[:buildpack]
      @buildpack ||= File.expand_path('.')
      super
    end

    def push!
      slug_url = nil

      begin
        stderr_orig = $stderr
        stdout_orig = $stdout
        string_io   = StringIO.new
        $stderr     = string_io
        slug_url    = Anvil::Engine.build(".", :buildpack => @buildpack, :pipeline => true)
        puts "Releasing to http://#{@name}.herokuapp.com"
        response = release(@name, slug_url)
        while response.status == 202
          response = Excon.get("#{release_host}#{response.headers["Location"]}")
        end
      rescue Anvil::Builder::BuildError => e
        output = $stderr.dup
        stdout_orig.puts output.string # print the errors to the test output
        return [false, output.string]
      ensure
        $stderr = stderr_orig
        $stdout = stdout_orig
      end

      [true, string_io.string]
    end

    def teardown!
      super
      FileUtils.rm_rf("#{directory}/.anvil")
    end

    private
    def release(name, slug_url)
      headers         = {"Content-Type" => "application/json", accept: :json}
      release_options = {description: "Anvil Build", slug_url: slug_url }
      Excon.post("#{release_host}/v1/apps/#{name}/release",
                 headers: headers,
                 body:    release_options.to_json)
    end

    def release_host
      "https://:#{api_key}@cisaurus.heroku.com"
    end
  end
end
