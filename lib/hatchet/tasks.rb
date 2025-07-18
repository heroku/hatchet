namespace :hatchet do
  task :setup_ci do
    script = File.expand_path(File.join(__dir__, "../../etc/ci_setup.rb"))
    puts "Running script `#{script}`"
    out = `#{script} 2>&1`
    puts "Done"
    puts "Output:\n"
    puts out
    raise "Command #{script.inspect} failed" unless $?.success?
  end

  task :setup_travis do
    Rake::Task["hatchet:setup_ci"].invoke
  end
end
