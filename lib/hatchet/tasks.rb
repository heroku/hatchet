namespace :hatchet do
  task :setup_ci do
    script = File.expand_path(File.join(__dir__, "../../etc/ci_setup.rb"))
    out = `#{script}`
    raise "Command #{script.inspect} failed\n#{out}"
  end

  task :setup_travis do
    Rake::Task["hatchet:setup_ci"].invoke
  end
end
