require 'rake'
require 'rake/testtask'

namespace :hatchet do
  task :setup_travis do
    `bundle exec hatchet install`
    # Disable stricthostkey checking
    `echo -e "Host heroku.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config`
    `echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config`
    # install toolbelt
    `wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh`
    # generate ssh keys
    `ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa`
    # login from HEROKU_API_KEY, clear then upload ssh keys
    `heroku keys:add`
    `heroku login`
  end
end