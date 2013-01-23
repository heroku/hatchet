module Hatchet
  class AnvilApp < App
    def setup!
      super
      heroku.post_app(name: name)
    end

    def push!
      Anvil::Engine.build(".", :buildpack => @buildpack)
    end
  end
end
