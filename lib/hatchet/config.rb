module Hatchet
  class MissingConfig < Errno::ENOENT
    def initialize
      super("could not find a 'hatchet.json' file in root directory")
    end
  end
  class ParserError   < JSON::ParserError;  end
  class BadRepoName   < StandardError
    def initialize(name, paths)
      msg = "could not find repo: '#{name}', check for spelling or " <<
            "duplicate repos. Run `$ hatchet list` to see all "   <<
            "repo options. Checked in #{paths.inspect}. \n\n" <<
            "  make sure repos are installed by running `$ hatchet install`"
      super(msg)
    end
  end

  # This class is responsible for parsing hatchet.json into something
  # meaninful.
  class Config
    REPOS_DIR_NAME       = "repos" # the top level name of repos folder
    REPOS_DIRECTORY_ROOT = '.'     # the the root directory where your repos folder will be stored

    attr_accessor :repos, :dirs

    def repo_directory_path
      File.join(@repo_directory_path, REPOS_DIR_NAME)
    end

    # creates new config object, pass in directory where `heroku.json`
    # is located
    def initialize(directory = '.')
      self.repos = {}
      self.dirs  = {}
      Dir.chdir(directory) do
        config_file = File.open('hatchet.json').read
        init_config! JSON.parse(config_file)
      end
    rescue Errno::ENOENT
      raise MissingConfig
    rescue JSON::ParserError => e
      raise ParserError, "Improperly formatted json in 'hatchet.json' \n\n" + e.message
    end

    # use this method to turn "codetriage" into repos/rails3/codetriage
    def path_for_name(name)
      possible_paths = [repos[name.to_s], "repos/#{name}", name].compact
      path = possible_paths.detect do |path|
        !(Dir[path] && Dir[path].empty?)
      end
      raise BadRepoName.new(name, possible_paths) if path.nil? || path.empty?
      path
    end

    # 'git@github.com:codetriage/codetriage.git' => 'codetriage'
    def name_from_git_repo(repo)
      repo.split('/').last.chomp('.git')
    end

  private

    def set_internal_config!(config)
      @internal_config     = config.delete('hatchet') || {}
      @repo_directory_path = @internal_config['directory'] || REPOS_DIRECTORY_ROOT
      config
    end

    # pulls out config and makes easy to use hashes
    # dirs has the repo paths as keys and the git_repos as values
    # repos has repo names as keys and the paths as values
    def init_config!(config)
      set_internal_config!(config)
      config.each do |(directory, git_repos)|
        git_repos.each do |git_repo|
          git_repo         = git_repo.include?("github.com") ? git_repo : "https://github.com/#{git_repo}.git"
          repo_name        = name_from_git_repo(git_repo)
          repo_path        = File.join(repo_directory_path, directory, repo_name)
          if repos.key? repo_name
            puts "  warning duplicate repo found: #{repo_name.inspect}"
            repos[repo_name] = false
          else
            repos[repo_name] = repo_path
          end
          dirs[repo_path]  = git_repo
        end
      end
    end
  end
end

