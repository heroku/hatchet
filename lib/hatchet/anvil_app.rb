module Hatchet
  class AnvilApp < App
    def setup!
      heroku.post_app(name: name)
      @app_is_setup = true
    end

    def push!
      Anvil::Engine.build(".", :buildpack => @buildpack)
    end
  end
end
