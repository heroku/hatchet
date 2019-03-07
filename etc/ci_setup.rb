#!/usr/bin/env ruby
require 'bundler'
require 'shellwords'
puts "== Setting Up CI =="

netrc_file = "#{ENV['HOME']}/.netrc"
unless File.exists?(netrc_file)
  File.open(netrc_file, 'w') do |file|
    file.write <<-EOF
machine git.heroku.com
login #{ENV.fetch('HEROKU_API_USER')}
password #{ENV.fetch('HEROKU_API_KEY')}
EOF
  end
end

[
 "bundle exec hatchet ci:install_heroku",
 "bundle exec hatchet install",
 "git config --get user.email > /dev/null || git config --global user.email #{ENV.fetch('HEROKU_API_USER').shellescape}",
 "git config --get user.name > /dev/null || git config --global user.name 'BuildpackTester'",
].each do |command|
  puts "== Running: #{command}"
  Bundler.with_clean_env do
    result = `#{command}`
    raise "Command failed: #{command.inspect}\nResult: #{result}" unless $?.success?
  end
end
puts "== Done =="
