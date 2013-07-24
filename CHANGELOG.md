## HEAD

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
