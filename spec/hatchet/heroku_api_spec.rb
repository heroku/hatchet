require("spec_helper")
describe "HerokuApiTest" do
  it "config vars" do
    begin
      runner = Hatchet::Runner.new("no_lockfile").setup!
      actual = runner.get_config
      actual.delete("BUILDPACK_URL")
      expect(actual).to eq({})

      runner.set_config("foo" => "bar")

      actual = runner.get_config
      actual.delete("BUILDPACK_URL")
      expect(actual).to eq({ "foo" => "bar" })
    ensure
      runner.teardown! if runner
    end
  end

  it "config vars in init" do
    begin
      runner = Hatchet::Runner.new("no_lockfile", config: { foo: "bar" }).setup!
      actual = runner.get_config

      expect(actual).to eq({ "foo" => "bar" })
    ensure
      runner.teardown! if runner
    end
  end
end
