require 'test_helper'

class AllowFailureAnvilTest < Test::Unit::TestCase

  def setup
    @buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'
  end

  # def test_allowed_failure
  #   Hatchet::AnvilApp.new("no_lockfile", buildpack: @buildpack_path, allow_failure: true).deploy do |app, heroku, output|
  #     refute app.deployed?
  #     assert_match "Gemfile.lock required", output
  #   end
  # end

  # def test_failure_with_no_flag
  #   assert_raise(Anvil::Builder::BuildError) do
  #     Hatchet::AnvilApp.new("no_lockfile", buildpack: @buildpack_path).deploy
  #   end
  # end

  # def test_retries
  #   orig_retries = Hatchet::RETRIES
  #   Hatchet.const_set(:RETRIES, 2)
  #   assert_raise(Anvil::Builder::BuildError) do
  #     app = Hatchet::AnvilApp.new("no_lockfile", buildpack: @buildpack_path)
  #     app.expects(:push_without_retry!).twice.raises(Anvil::Builder::BuildError)
  #     app.deploy
  #   end
  # ensure
  #   Hatchet.const_set(:RETRIES, orig_retries)
  # end
end
