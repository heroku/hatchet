#!/usr/bin/env ruby
require 'shellwords'

STDOUT.sync = true

def run_cmd(command)
  puts "== Running: #{command}"
  result = `#{command}`
  raise "Command failed: #{command.inspect}\nResult: #{result}" unless $?.success?
end

puts "== Setting Up CI =="

netrc_file = "#{ENV['HOME']}/.netrc"
unless File.exist?(netrc_file)
  File.open(netrc_file, 'w') do |file|
    file.write <<-EOF
machine git.heroku.com
  login #{ENV.fetch('HEROKU_API_USER')}
  password #{ENV.fetch('HEROKU_API_KEY')}
machine api.heroku.com
  login #{ENV.fetch('HEROKU_API_USER')}
  password #{ENV.fetch('HEROKU_API_KEY')}
EOF
    run_cmd 'chmod 0600 "$HOME/.netrc"'
  end
end

run_cmd "bundle exec hatchet ci:install_heroku"
run_cmd "bundle exec hatchet install"
run_cmd "git config --get user.email > /dev/null || git config --global user.email #{ENV.fetch('HEROKU_API_USER').shellescape}"
run_cmd "git config --get user.name > /dev/null || git config --global user.name 'BuildpackTester'"
# Suppress the `git init` warning in Git 2.30+ when no default branch name is set.
run_cmd "git config --global init.defaultBranch main"

puts "== Done =="

