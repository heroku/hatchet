require "spec_helper"

describe "GitAppTest" do
  it "can deploy git app to the main branch" do
    Hatchet::GitApp.new("lock_fail_main", allow_failure: true).deploy do |app|
      expect(app.output).to match("INTENTIONAL ERROR")
    end
  end
end
