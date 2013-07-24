require 'rake'
require 'rake/testtask'

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
    ['bundle exec hatchet install',
     "echo '#{config_ssh}' >> ~/.ssh/config",
     'wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh',
     'heroku keys:clear',
     'yes | heroku keys:add'
    ].each do |command|
      puts "== Running: #{command}"
      `#{command}`
    end
    puts "== Done =="
  end

  task :teardown_travis do
    ['heroku keys:remove ~/.ssh/id_rsa'].each do |command|
      puts "== Running: #{command}"
      `#{command}`
    end
  end
end
