require 'test_helper'

class AnvilTest < Test::Unit::TestCase
  def setup
    @buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'
  end
end
