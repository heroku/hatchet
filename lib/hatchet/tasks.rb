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
    netrc = "#{ENV['HOME']}/.netrc"
    unless File.exists?(netrc)
      File.open(netrc, 'w') do |file|
        file.write <<EOF
machine git.heroku.com
  login #{ENV.fetch('HEROKU_API_USER')}
  password #{ENV.fetch('HEROKU_API_KEY')}
EOF
      end
    end
    [
     "bundle exec hatchet install",
     "if [ `git config --get user.email` ]; then echo 'already set'; else `git config --global user.email '#{ENV.fetch('HEROKU_API_USER')}'`; fi",
     "if [ `git config --get user.name` ];  then echo 'already set'; else `git config --global user.name  'BuildpackTester'`      ; fi",
     "echo '#{config_ssh}' >> ~/.ssh/config",
     "ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''",
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
