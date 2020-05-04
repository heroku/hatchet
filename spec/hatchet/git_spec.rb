require "spec_helper"

describe "GitAppTest" do
  it "can deploy git app" do
    Hatchet::GitApp.new("rails5_ruby_schema_format").deploy do |app|
      expect(app.run("ruby -v")).to match("2.6.6")
    end
  end
end
