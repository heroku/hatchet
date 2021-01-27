## HEAD

- Memoize `Hatchet::App.default_buildpack` (https://github.com/heroku/hatchet/pull/183)
- Fix repository path lookup when custom Hatchet directory set (https://github.com/heroku/hatchet/issues/181)
- Handle additional variations of rate limit error messages (https://github.com/heroku/hatchet/pull/182)
- Add `HATCHET_DEFAULT_STACK` for configuring the default stack (https://github.com/heroku/hatchet/pull/184)
- Fix typo in the reaper `"Duplicate destroy attempted"` message (https://github.com/heroku/hatchet/pull/175)
- Set `init.defaultBranch` in ci:setup to suppress `git init` warning in Git 2.30+ (https://github.com/heroku/hatchet/issues/172)
- Switch `heroku ci:install_heroku` to the Heroku CLI standalone installer rather than the APT install method (https://github.com/heroku/hatchet/issues/171)

## 7.3.3

- Quiet personal tokens (https://github.com/heroku/hatchet/pull/148)

## 7.3.2

- Fix App#in_directory_fork not receiving debugging output when an error is raised (https://github.com/heroku/hatchet/pull/146)
- Do not create CI tarball inside cwd to prevent tar "file changed as we read it" warnings.

## 7.3.1

- Fix Ruby incompatibility introduced by using `&.` and `rescue` without
  `begin`/`end` without a `required_ruby_version` in hatchet.gemspec.
  (https://github.com/heroku/hatchet/pull/139)

## 7.3.0

- Deprecations
  - Deprecation: Calling `App#before_deploy` as a way to clear/replace the existing block should now be done with `App#before_deploy(:replace)` (https://github.com/heroku/hatchet/pull/126)
  - Deprecation: HATCHET_BUILDPACK_BASE default (https://github.com/heroku/hatchet/pull/133)
  - Deprecation: App#directory (https://github.com/heroku/hatchet/pull/135)

- Flappy test improvements
  - Increase CI timeout limit to 900 seconds (15 minutes) (https://github.com/heroku/hatchet/pull/137)
  - Empty string returns from App#run now trigger retries (https://github.com/heroku/hatchet/pull/132)
  - Rescue 403 on pipeline delete (https://github.com/heroku/hatchet/pull/130)
  - Additional rate throttle cases handled (https://github.com/heroku/hatchet/pull/128)

- Usability
  - Annotate rspec expectation failures inside of deploy blocks with hatchet debug information (https://github.com/heroku/hatchet/pull/136)
  - Hatchet#new raises a helpful error when no source code location is provided (https://github.com/heroku/hatchet/pull/134)
  - Lazy evaluation of HATCHET_BUILDPACK_BASE env var (https://github.com/heroku/hatchet/pull/133)
  - Allow multiple `App#before_deploy` blocks to be set and called (https://github.com/heroku/hatchet/pull/126)
  - Performance improvement when running without an explicit HEROKU_API_KEY set (https://github.com/heroku/hatchet/pull/128)

## 7.2.0

- App#setup! no longer modifies files on disk. (https://github.com/heroku/hatchet/pull/125)
- Add `$ hatchet init` command for bootstrapping new projects (https://github.com/heroku/hatchet/pull/123)

## 7.1.3

- Important!! Fix branch name detection on CircleCI (https://github.com/heroku/hatchet/pull/124)

## 7.1.2

- Fix support for Hatchet deploying the 'main' branch (https://github.com/heroku/hatchet/pull/122)

## 7.1.1

- Fix destroy_all functionality (https://github.com/heroku/hatchet/pull/121)

## 7.1.0

- Initializing an `App` can now take a `retries` key to overload the global hatchet env var (https://github.com/heroku/hatchet/pull/119)
- Calling `App#commit!` now adds an empty commit if there is no changes on disk (https://github.com/heroku/hatchet/pull/119)
- Bugfix: Failed release phase in deploys can now be re-run (https://github.com/heroku/hatchet/pull/119)
- Bugfix: Allow `hatchet lock` to be run against new projects (https://github.com/heroku/hatchet/pull/118)
- Bugfix: Allow `hatchet.lock` file to lock a repo to a different branch than what is specified as default for GitHub (https://github.com/heroku/hatchet/pull/118)

## 7.0.0

- ActiveSupport's Object#blank? and Object#present? are no longer provided by default (https://github.com/heroku/hatchet/pull/107)
- Remove deprecated support for passing a block to `App#run` (https://github.com/heroku/hatchet/pull/105)
- Ignore  403 on app delete due to race condition (https://github.com/heroku/hatchet/pull/101)
- The hatchet.lock file can now be locked to "main" in addition to "master" (https://github.com/heroku/hatchet/pull/86)
- Allow concurrent one-off dyno runs with the `run_multi: true` flag on apps (https://github.com/heroku/hatchet/pull/94)
- Apps are now marked as being "finished" by enabling maintenance mode on them when `teardown!` is called. Finished apps can be reaped immediately (https://github.com/heroku/hatchet/pull/97)
- Applications that are not marked as "finished" will be allowed to live for a HATCHET_ALIVE_TTL_MINUTES duration before they're deleted by the reaper to protect against deleting an app mid-deploy, default is seven minutes (https://github.com/heroku/hatchet/pull/97)
- The HEROKU_APP_LIMIT env var no longer does anything, instead hatchet application reaping is manually executed if an app cannot be created (https://github.com/heroku/hatchet/pull/97)
- App#deploy without a block will no longer run `teardown!` automatically (https://github.com/heroku/hatchet/pull/97)
- Calls to `git push heroku` are now rate throttled (https://github.com/heroku/hatchet/pull/98)
- Calls to `app.run` are now rate throttled (https://github.com/heroku/hatchet/pull/99)
- Deployment now raises and error when the release failed (https://github.com/heroku/hatchet/pull/93)

## 6.0.0

- Rate throttling is now provided directly by `platform-api` (https://github.com/heroku/hatchet/pull/82)

## 5.0.3

- Allow repos to be "locked" to master instead of a specific commit (https://github.com/heroku/hatchet/pull/80)

## 5.0.2

- Fix `before_deploy` use with ci test runs (https://github.com/heroku/hatchet/pull/78)

## 5.0.1

- Circle CI support in `ci:setup` command (https://github.com/heroku/hatchet/pull/76)

## 5.0.0

- Shelling out to `heroku` commands no longer uses `Bundler.with_clean_env` (https://github.com/heroku/hatchet/pull/74)
- CI runs can now happen multiple times against the same app/pipeline (https://github.com/heroku/hatchet/pull/75)
- Breaking change: Do not allow App#run to escape to system shell by default (https://github.com/heroku/hatchet/pull/72)

> Note: If you were relying on this behavior, use the `raw: true` option.

- ReplRunner use with App#run is now deprecated (https://github.com/heroku/hatchet/pull/72)
- Calling App#run with a nil in the second argument is now deprecated (https://github.com/heroku/hatchet/pull/72)

## 4.1.2

- Hatchet::App.default_buildpack is aliased to `:default` symbol while passing in buildpacks as an array to Hatchet::App (https://github.com/heroku/hatchet/pull/73)

## 4.1.1

- Fix branch resolution on Travis when a pull-request is tested (https://github.com/heroku/hatchet/pull/70)

## 4.1.0

- Fix CI 403 errors caused by Heroku auto deleting pipelines that do not have an app attached (https://github.com/heroku/hatchet/pull/68)
- CI runs now default to `heroku-18` this is a breaking change (https://github.com/heroku/hatchet/pull/68)

## 4.0.13

- Introduce `App#in_directory_fork` for safe execution of code that might mutate the process env vars (https://github.com/heroku/hatchet/pull/65)

## 4.0.12

- Fix deadlock when a single process kills the same app twice (https://github.com/heroku/hatchet/pull/63)
- Add ability to debug deadlock with `HATCHET_DEBUG_DEADLOCK` env var.

## 4.0.11

- Fix logic in rake task (https://github.com/heroku/hatchet/pull/62)

## 4.0.10

- Fix syntax in rake task (https://github.com/heroku/hatchet/pull/61)

## 4.0.9

- Allow overriding of all App#run options, including option removal (by passing `Hatchet::App::SkipDefaultOption` as the value)

## 4.0.8

- Fix `hatchet destroy` calling class from wrong module
- Fix `hatchet destroy` not passing rate limited API to Reaper
- Fix undeclared variable in `App#create_app` rescue block
- Fix race condition in `Reaper#cycle` triggering 403s in API, causing test failures
- Allow configurable app name prefix (default "hatchet-t-") via `HATCHET_APP_PREFIX` env var

## 4.0.7

- Exit code is now returned from `app.run` commands (https://github.com/heroku/hatchet/pull/58)
- ci_setup.rb no longer emits an error when run on `sh` (https://github.com/heroku/hatchet/pull/57)

## 4.0.6

- Setup script `hatchet ci:setup` added (https://github.com/heroku/hatchet/pull/55)

## 4.0.5

- Allow for using locally checked in repo and skip the hatchet.lock dance (https://github.com/heroku/hatchet/pull/53)

## 4.0.4 - release not found

- Allow setting config when object is initialized (https://github.com/heroku/hatchet/pull/52)

## 4.0.3

- Introduce explicit `before_deploy` block that is called, well...before deploy happens. If any changes are made to disk at this time then contents are committed to disk (https://github.com/heroku/hatchet/pull/51)
- Allow running `deploy` block inside of an `in_directory` block (https://github.com/heroku/hatchet/pull/51)
- Introduce Hatchet::App#commit! that will commit any files to a repo in the current directory. (https://github.com/heroku/hatchet/pull/51)

## 4.0.2

- Support for running Hatchet tests on Heroku CI by defaulting to `ENV['HEROKU_TEST_RUN_BRANCH']` (#48)

## 4.0.1

- Rate limit Heroku CI

## 4.0.0

- Introduce API rate limiting (#46)
- Deprecate App#platform_api method (#46)

## 3.1.1

- Better errors when no lockfile is found #43

## 3.1.0

- Introduce a lockfile #42

## 3.0.6

- Fix double delete error #41

## 3.0.5

- Require `mktmpdir` in the right place.

## 3.0.4

- Remove Heroku constants

## 3.0.2

- SSH no longer needed for travis setup
- Remove Heroku.rb dependency

## 3.0.2

- Use https for git clones

## 3.0.1

- Can pass in multiple buildpacks to constructor
- app#update_stack() added
- Can pass stack into constructor
- Added `Hatchet::App.default_buildpack`

## 3.0.0

- Use v3 of the Heroku API because Heroku is deprecating v2

## 2.0.3

- Fix CI support to include multi nodes of output.

## 2.0.2

- Do not require super user access

## 2.0.1

- Use actual email address instead of example

## 2.0.0

- Support for Heroku CI added
- Removed support for Anvil

## 1.4.1

- Shell commands now escaped automatically

## 1.4.0

- The App#setup! method now automatically tries to reap unused apps if the request fails.
- Default app deploy type is now :git

## 1.3.7

- Return self from setup!

## 1.3.6

- Re-push of 1.3.5 with actual commits.

## 1.3.5

- Ensure travis box has an SSH key

## 1.3.4

- Ignore when we try to delete an app that does not exist

## 1.3.3

- Apps are lazily reaped for easier debugging
- Verbose output by default for easier debugging

## 1.3.2 (02-18-2014)

- App#run interface now matches ReplRunner

## 1.3.1

- Fix dependencies

## 1.3.0

- `hatchet install` now clones and pulls in parallel threads
- `rake travis:setup` now ensures a git email and name is set

## 1.2.1

- Remove debug puts

## 1.2.0

- Change `App#push` default behavior to be `App#push_with_retry!`
- `App#in_directory` now copies source repo to tmpdir so it can be modified if needed
- Repo name now shows up in error outputs.

## 1.1.9

- Use TRAVIS_BRANCH if present

## 1.1.8

- Do not check git branch unless using GitApp

## 1.1.7

- Add labs methods `App#set_labs!` and `App.new(labs: "websockets")`

## 1.1.6
- `App#setup!` is now idempotent
- Added `App#get_config`
- Added `App#set_config`

## 1.1.5
- Add `App#in_directory` to public API

## 1.1.4
- Bugfix: Eliminate race condition around running multiple travis builds at the same time

## 1.1.3

- Bugfix: use clean bundler env when setting up travis.

## 1.1.2

- Bugfix: test setup on travis now works correctly

## 1.1.1

- Ensure external commands run inside of `bundle_exec` block are run with proper environment variables set.

## 1.1.0

- Added `Hatchet::Runner` which can dynamically swap the backend (anvil/git) depending on the value of ENV['HATCHET_DEPLOY_STRATEGY'] you can use 'anvil' or 'git'.

## 1.0.0

- Move remote console running code to https://github.com/schneems/repl_runner
  This changes the API for running interactive code. README has been updated

## 0.2.0

- Add database method App#add_database

- Drastically improved reliability of `app.run` outputs.

- Add `rake hatchet:teardown_travis` task to put in `travis.yml`:

    after_script: bundle exec rake hatchet:teardown_travis

## 0.1.1

- Allow auto retries of pushes by setting environment variable `HATCHET_RETRIES=3`

## 0.1.0

- Failed deploys now raise an exception, to ignore set `allow_failure: true` in the `Hatchet::App`

## 0.0.2

- Added ability to run inline commands with no block (such as `app.run('ruby -v')`)

## 0.0.1

- Initial Release
