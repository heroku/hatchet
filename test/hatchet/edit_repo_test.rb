require 'test_helper'

class EditRepoTest < Minitest::Test
  def test_can_deploy_git_app
    Hatchet::GitApp.new("default_ruby").in_directory do |app|
      msg = `touch foo`
      assert $?.success?, msg

      msg = `git add .; git commit -m foo`
      assert $?.success?, msg

      assert_match "foo", `ls`
    end

    Hatchet::GitApp.new("default_ruby").in_directory do |app|
      refute_match /foo/, `ls`
    end
  end
end

