module Hatchet
  class GitApp < App
    def setup!
      super
      heroku.put_config_vars(name, 'BUILDPACK_URL' => @buildpack)
    end

    def push!
      output = `git push #{git_repo} master`
      [$?.success?, output]
    end
  end
end
