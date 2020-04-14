require 'test_helper'

class CIFourTest < Minitest::Test
  def test_error_with_bad_app
    string = SecureRandom.hex
    Hatchet::GitApp.new("default_ruby").run_ci do |test_run|
      refute_match(string, test_run.output)
      assert_match("Installing rake" , test_run.output)

      run!(%Q{echo 'puts "#{string}"' >> Rakefile})
      test_run.run_again

      assert_match(string, test_run.output)
      assert_match("Using rake" , test_run.output)

      refute_match("Installing rake" , test_run.output)
    end
  end
end
