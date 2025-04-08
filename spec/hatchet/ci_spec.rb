require "spec_helper"

describe "CI" do
  it "runs rakefile contents" do
    string = SecureRandom.hex

    app = Hatchet::GitApp.new("default_ruby")
    app.run_ci do |test_run|
      expect(test_run.output).to_not match(string)
      expect(test_run.output).to match("Installing rake")

      run!("echo 'puts \"#{string}\"' >> Rakefile")
      test_run.run_again

      expect(test_run.output).to match(string)
      expect(test_run.output).to_not match("Installing rake")
    end
  end
end
