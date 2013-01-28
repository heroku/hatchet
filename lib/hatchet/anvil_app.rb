require 'json'
require 'stringio'

module Hatchet
  class AnvilApp < App
    def push!
      slug_url = nil

      begin
        stderr_orig = $stderr
        stdout_orig = $stdout
        $stderr = StringIO.new
        slug_url = Anvil::Engine.build(".", :buildpack => @buildpack, :pipeline => true)
      rescue Anvil::Builder::BuildError => e
        output = $stderr.dup
        return [false, output.string]
      ensure
        $stderr = stderr_orig
        $stdout = stdout_orig
      end

      puts "Releasing to http://#{@name}.herokuapp.com"
      response = release(@name, slug_url)
      while response.status == 202
        response = Excon.get("#{release_host}#{response.headers["Location"]}")
      end

      output = $stderr.dup

      [true, output.string]
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
