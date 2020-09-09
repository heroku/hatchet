require 'thor'
require 'yaml'

module Hatchet
  # Bootstraps a project with files for running hatchet tests
  #
  #   Hatchet::InitProject.new.call
  #
  #   puts File.exist?("spec/spec_helper.rb") # => true
  #   puts File.exist?("") # => true
  class InitProject
    def initialize(dir: ".", io: STDOUT)

      @target_dir = Pathname.new(dir)
      raise "Must run in a directory with a buildpack, #{@target_dir} has no bin/ directory" unless @target_dir.join("bin").directory?

      @template_dir = Pathname.new(__dir__).join("templates")
      @thor_shell = ::Thor::Shell::Basic.new
      @io = io
      @git_ignore = @target_dir.join(".gitignore")

      FileUtils.touch(@git_ignore)
      FileUtils.touch(@target_dir.join("hatchet.lock"))
    end

    def call
      write_target(target: ".circleci/config.yml", template: "circleci_template.erb")
      write_target(target: "Gemfile", template: "Gemfile.erb")
      write_target(target: "hatchet.json", template: "hatchet_json.erb")
      write_target(target: "spec/spec_helper.rb", template: "spec_helper.erb")
      write_target(target: "spec/hatchet/buildpack_spec.rb", template: "buildpack_spec.erb")
      write_target(target: ".github/dependabot.yml", template: "dependabot.erb")
      write_target(target: ".github/workflows/check_changelog.yml", template: "check_changelog.erb")

      add_gitignore(".rspec_status")
      add_gitignore("repos/*")

      stream("cd #{@target_dir} && bundle install")
      stream("cd #{@target_dir} && hatchet install")

      @io.puts
      @io.puts "Done, run `bundle exec rspec` to execute your tests"
      @io.puts
    end

    private def add_gitignore(statement)
      @git_ignore.open("a") {|f| f.puts statement } unless @git_ignore.read.include?(statement)
    end

    private def stream(command)
      output = ""
      IO.popen(command) do |io|
        until io.eof?
          buffer = io.gets
          output << buffer
          @io.puts(buffer)
        end
      end
      raise "Error running #{command}. Output:\n#{output}" unless $?.success?
      output
    end

    private def write_target(template: nil, target:, contents: nil)
      if template
        template = @template_dir.join(template)
        contents = ERB.new(template.read).result(binding)
      end

      target = @target_dir.join(target)
      target.dirname.mkpath # Create directory if it doesn't exist already

      if target.exist?
        return if contents === target.read # identical
        target.write(contents) if @thor_shell.file_collision(target) { contents }
      else
        target.write(contents)
      end
    end

    private def cmd(command)
      result = `#{command}`.chomp
      raise "Command #{command} failed:\n#{result}" unless $?.success?
      result
    end
  end
end
