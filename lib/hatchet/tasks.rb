config_ssh = <<-RUBY

Host heroku.com
    StrictHostKeyChecking no
    CheckHostIP no
    UserKnownHostsFile=/dev/null
Host github.com
    StrictHostKeyChecking no
RUBY

namespace :hatchet do
  task :setup_travis do
    puts "== Setting Up Travis =="
    [
     "bundle exec hatchet install",
     "if [ `git config --get user.email` ]; then echo 'already set'; else `git config --global user.email 'buildpack@example.com'`; fi",
     "if [ `git config --get user.name` ];  then echo 'already set'; else `git config --global user.name  'BuildpackTester'`      ; fi",
     "echo '#{config_ssh}' >> ~/.ssh/config",
     "curl --fail --retry 3 --retry-delay 1 --connect-timeout 3 --max-time 30 https://toolbelt.heroku.com/install-ubuntu.sh | sh",
     "yes | heroku keys:add"
    ].each do |command|
      puts "== Running: #{command}"
      Bundler.with_clean_env do
        result = `#{command}`
        raise "Command failed: #{command.inspect}\nResult: #{result}" unless $?.success?
      end
    end
    puts "== Done =="
  end

  task :teardown_travis do
    ['heroku keys:remove'].each do |command|
      puts "== Running: #{command}"
      `#{command}`
    end
  end
end

