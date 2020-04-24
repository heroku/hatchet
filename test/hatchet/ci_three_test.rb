require 'test_helper'

class CIThreeTest < Minitest::Test
  def test_error_with_bad_app
    @before_deploy_called = false
    @before_deploy_dir_pwd = nil
    before_deploy = -> {
      @before_deploy_called = true
      @before_deploy_dir_pwd = Dir.pwd
    }
    Hatchet::GitApp.new("rails5_ci_fails_no_database", allow_failure: true, before_deploy: before_deploy).run_ci do |test_run|
      assert_equal :errored, test_run.status
      assert_equal Dir.pwd, @before_deploy_dir_pwd

      assert @before_deploy_called
    end

    refute_equal Dir.pwd, @before_deploy_dir_pwd
  end
end
