require "spec_helper"

# Tests in this file do not deploy to Heroku
describe "App unit tests" do
  it "annotates rspec expectation failures" do
    app = Hatchet::Runner.new("default_ruby")
    error = nil
    begin
      app.annotate_failures do
        expect(true).to eq(false)
      end
    rescue RSpec::Expectations::ExpectationNotMetError => e
      error = e
    end

    expect(error.message).to include(app.name)
  end

  it "calls reaper if cannot create an app" do
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    def app.heroku_api_create_app(*args); raise StandardError.new("made you look"); end

    reaper = app.reaper

    def reaper.destroy_older_apps(*args, **kwargs, &block); @app_exception_message = true; end
    def reaper.clean_old_was_called?; @app_exception_message; end

    expect {
      app.create_app
    }.to raise_error("made you look")

    expect(reaper.clean_old_was_called?).to be_truthy
  end

  it "app with default" do
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    expect(app.buildpacks.first).to match("https://github.com/heroku/heroku-buildpack-ruby")
  end

  it "default_buildpack is only computed once" do
    expect(Hatchet::App.default_buildpack.object_id).to eq(Hatchet::App.default_buildpack.object_id)
  end

  it "nested deploy block only calls teardown once" do
    @deploy = 0
    app = Hatchet::App.new("default_ruby", buildpacks: [:default])
    def app.in_dir_setup!; ;end # Don't create an app
    def app.push_with_retry!; end # Don't try pushing to it
    def app.teardown!; @teardown ||=0; @teardown += 1 end
    def app.get_teardown_count; @teardown; end

    app.deploy do |app|
      @deploy += 1
      app.deploy do |app|
        @deploy += 1
      end
      app.deploy do |app|
        @deploy += 1
      end
    end

    expect(app.get_teardown_count).to eq(1)
    expect(@deploy).to eq(3)
  end
end
