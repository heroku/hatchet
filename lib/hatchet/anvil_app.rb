require 'json'
require 'stringio'

module Hatchet
  class AnvilApp < App

    def initialize(directory, options = {})
      @buildpack = options[:buildpack]
      @buildpack ||= File.expand_path('.')
      super
    end

    def push!
      out, err = wrap_stdout_and_rescue(Anvil::Builder::BuildError) do
        slug_url  = Anvil::Engine.build(".", :buildpack => @buildpack, :pipeline => true)
        puts "Releasing to http://#{@name}.herokuapp.com"
        response = release(@name, slug_url)
        while response.status == 202
          response = Excon.get("#{release_host}#{response.headers["Location"]}")
        end
      end

      err.string
    end

    def wrap_stdout_and_rescue(error, &block)
      wrap_stdout do |orig_out, orig_err|
        begin
          yield orig_out, orig_err
        rescue error => e
          return [$stdout.dup, $stderr.dup] if @allow_failure
          orig_out.puts $stderr.dup.string # print the errors to the test output
          raise e
        end
      end
    end

    def wrap_stdout(orig_out = $stdout, orig_err = $stderr, &block)
      $stderr  = StringIO.new
      $stdout  = StringIO.new
      yield orig_out, orig_err
      puts [$stdout.dup, $stderr.dup].inspect
      return $stdout.dup, $stderr.dup
    ensure
      $stdout = orig_out
      $stderr = orig_err
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
