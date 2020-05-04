require("spec_helper")
describe "EditRepoTest" do
  it "can deploy git app" do
    Hatchet::GitApp.new("default_ruby").in_directory do |app|
      `touch foo`
      expect($?.success?).to(eq(true))

      `git add .; git commit -m foo`
      expect($?.success?).to(eq(true))
      expect(`ls`).to(match("foo"))
    end

    Hatchet::GitApp.new("default_ruby").in_directory do |app|
      expect(`ls`).to_not match(/foo/)
    end
  end
end
