require 'rake'
require 'rake/testtask'

namespace :hatchet do
  task :setup_travis do
    puts "== Setting Up Travis =="
    ['bundle exec hatchet install',
     %Q{echo "\nHost heroku.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config},
     %Q{echo "\nHost github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config},
     'wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh',
     'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa',
     'heroku keys:add',
     'heroku login'
    ].each do |command|
      puts "== Running: #{command}"
      `#{command}`
    end
    puts "== Done =="
  end
end