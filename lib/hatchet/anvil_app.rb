module Hatchet
  class AnvilApp < App
    def push!
      Anvil::Engine.build(".", :buildpack => @buildpack)
    end
  end
end
