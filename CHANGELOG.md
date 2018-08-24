## HEAD

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

- Ensure external commands run inside of `bundle_exec` block are run with propper environment variables set.

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
