namespace :hatchet do
  task :setup_ci do
    puts "== Setting Up Travis =="
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
     "bundle exec hatchet install",
     "if [ `git config --get user.email` ]; then echo 'already set'; else `git config --global user.email '#{ENV.fetch('HEROKU_API_USER')}'`; fi",
     "if [ `git config --get user.name` ];  then echo 'already set'; else `git config --global user.name  'BuildpackTester'`      ; fi",
    ].each do |command|
      puts "== Running: #{command}"
      Bundler.with_clean_env do
        result = `#{command}`
        raise "Command failed: #{command.inspect}\nResult: #{result}" unless $?.success?
      end
    end
    puts "== Done =="
  end

  task :setup_travis do
    Rake::Task["hatchet:setup_ci"].invoke
  end
end
