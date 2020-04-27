# Hatchet

![](http://f.cl.ly/items/2M2O2Q2I2x0e1M1P2936/Screen%20Shot%202013-01-06%20at%209.59.38%20PM.png)

Hatchet is a an integration testing library for developing Heroku buildpacks.

## Install

First run:

    $ bundle install

This library uses the heroku CLI and API. You will need to make your API key available to the system. If you're running on a CI platform, you'll need to generate an OAuth token and make it available on the system you're running on see the "CI" section below.

## Run the Tests

    $ bundle exec rake test

## Why Test a Buildpack?

Testing a buildpack prevents regressions, and pushes out new features faster and easier.

## What can Hatchet Test?

Hatchet can easily test certain operations: deployment of buildpacks, getting the build output, and running arbitrary interactive processes (e.g. `heroku run bash`). Hatchet can also test running CI against an app.

## Writing Tests

Hatchet assumes a test framework doesn't exist. [This project](https://github.com/heroku/hatchet) uses `Test::Unit` to run it's own tests. While the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby) uses rspec.

Running `focused: true` in rspec allows you to choose which test to run and to tag tests. Rspec has useful plugins, such as `gem 'rspec-retry'` which will re-run any failed tests a given number of times (I recommend setting this to at least 2) to decrease false negatives in your tests.

Whatever testing framework you chose, we recommend using a parallel test runner when running the full suite. [Parallel_tests](https://github.com/grosser/parallel_tests) works with rspec and test::unit and is amazing.

If you're unfamiliar with the ruby testing eco-system or want some help, start by looking at existing projects.

*Spoilers*: There is a section below on getting Hatchet to work on CI

## Testing a Buildpack

Hatchet was built for testing the Ruby buildpack, but Hatchet can test any buildpack provided your tests are written in Ruby.

You will need copies of applications that can be deployed by your buildpack. You can see the ones for the Hatchet unit tests (and the Ruby buildpack) https://github.com/sharpstone. Hatchet does not require that you keep these apps checked into your git repo which would make fetching your buildpack slow, instead declare them in a `hatchet.json` file (see below).

Hatchet will automate retrieving these files `$ hatchet install`, deploy these files using your local copy of the buildpack, retrieve the build output and run commands against deploying applications.


## Hatchet.json

Hatchet expects a json file in the root of your buildpack called `hatchet.json`. You can configure install options using the `"hatchet"` key. In this example, we're telling Hatchet to install the given repos to our `test/fixtures` directory instead of the default current directory.

```
{
  "hatchet": {"directory": "test/fixtures"},
  "rails3":  ["sharpstone/rails3_mri_193"],
  "rails2":  ["sharpstone/rails2blog"],
  "bundler": ["sharpstone/no_lockfile"]
}
```

When you run `$ hatchet install` it will grab the git repos from github and place them on your local machine in a file structure that looks like this:

```
test/
  fixtures/
    repos/
      rails3/
        rails3_mri_193/
      rails2/
        rails2blog/
      bundler/
        no_lockfile/
```

You can reference one of these applications in your test by using it's git name:

```ruby
Hatchet::Runner.new('no_lockfile')
```

If you have conflicting names, use full paths.

To test with fixtures that are checked in locally, add the fixture directory to the path and skip the `hatchet install`:

```
Hatchet::Runner.new("spec/fixtures/repos/node-10-metrics")
```

Be careful when including repos inside of your test directory. If you're using a runner that looks for patterns such as `*_test.rb` to run your hatchet tests, it may run the tests inside of the repos. To prevent this problem, move your repos directory out of `test/` or into specific directories such as `test/hatchet`. Then change your pattern. If you are using `Rake::TestTask`, it might look like this:

    t.pattern = 'test/hatchet/**/*_test.rb'

When basing tests on external repos, do not change the tests or they may spontaneously fail. We may create a hatchet.lockfile or something to declare the commit in the future.

When you run `hatchet install` it will lock all the Repos to a specific commit. This is done so that if a repo changes upstream that introduces an error the test suite won't automatically pick it up. For example in https://github.com/sharpstone/lock_fail/commit/e61ba47043fbae131abb74fd74added7e6e504df an error is added, but this will only cause a failure if your project intentionally locks to commit `e61ba47043fbae131abb74fd74added7e6e504df` or later.

You can re-lock your projects by running `hatchet lock`. This modifies the `hatchet.lock` file. For example:

```
---
- - test/fixtures/repos/bundler/no_lockfile
  - 1947ce9a9c276d5df1c323b2ad78d1d85c7ab4c0
- - test/fixtures/repos/ci/rails5_ci_fails_no_database
  - 3044f05febdfbbe656f0f5113cf5968ca07e34fd
- - test/fixtures/repos/ci/rails5_ruby_schema_format
  - 3e63c3e13f435cf4ab11265e9abd161cc28cc552
- - test/fixtures/repos/default/default_ruby
  - 6e642963acec0ff64af51bd6fba8db3c4176ed6e
- - test/fixtures/repos/lock/lock_fail
  - da748a59340be8b950e7bbbfb32077eb67d70c3c
- - test/fixtures/repos/lock/lock_fail_master
  - master
- - test/fixtures/repos/rails2/rails2blog
  - b37357a498ae5e8429f5601c5ab9524021dc2aaa
- - test/fixtures/repos/rails3/rails3_mri_193
  - 88c5d0d067cfd11e4452633994a85b04627ae8c7
```

If you don't want to lock a specific commit, you can instead specify `master` and it will always grab the latest commits.


## Deploying apps


You can specify the location of your public buildpack url in an environment variable:

```sh
HATCHET_BUILDPACK_BASE=https://github.com/heroku/heroku-buildpack-ruby.git
HATCHET_BUILDPACK_BRANCH=master
```

If you do not specify `HATCHET_BUILDPACK_URL` the default Ruby buildpack will be used. If you do not specify a `HATCHET_BUILDPACK_BRANCH` the current branch you are on will be used. This is how the Ruby buildpack runs tests on branches on CI (by leaving `HATCHET_BUILDPACK_BRANCH` blank).

If the `ENV['HATCHET_RETRIES']` is set to a number, deploys are expected to work and automatically retry that number of times. Due to testing using a network and random failures, setting this value to `3` retries seems to work well. If an app cannot be deployed within its allotted number of retries, an error will be raised.

If you are testing an app that is supposed to fail deployment, you can set the `allow_failure: true` flag when creating the app:

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
```

After the block finishes, your app will be queued to be removed from heroku. If you are investigating a deploy, you can add the `debug: true` flag to your app:

```ruby
Hatchet::Runner.new("rails3_mri_193", debug: true).deploy do |app|
```

After Hatchet is done deploying your app, it will remain on Heroku. It will also output the name of the app into your test logs so that you can `heroku run bash` into it for detailed postmortem.

If you are wanting to run a test against a specific app without deploying to it, you can specify the app name like this:

```ruby
app = Hatchet::Runner.new("rails3_mri_193", name: "testapp")
```

Deploying the app takes a few minutes. You may want to skip deployment to make debugging faster.

If you need to deploy using a different buildpack you can specify one manually:

```ruby

def test_deploy
  Hatchet::Runner.new("rails3_mri_193", buildpack: "https://github.com/heroku/heroku-buildpack-ruby.git").deploy do |app|
  # ...
```

You can specify multiple buildpacks by passing in an array. When you do that you also need to tell hatchet where to place your buildpack. Since hatchet needs to build your buildpack from a branch you should not hardcode a path like `heroku/ruby` instead Hatchet has a replacement mechanism. Use the `:default` symbol where you want your buildpack to execute. For example:

```
Hatchet::Runner.new("default_ruby", buildpacks: [:default, "https://github.com/pgbouncer/pgbouncer"])
```

That will expand your buildpack and branch. For example if you're on the `update_readme` branch of the `heroku-buildpack-ruby` buildpack it would expand to:

```
Hatchet::Runner.new("default_ruby", buildpacks: ["https://github.com/heroku/heroku-buildpack-ruby#update_readme", "https://github.com/pgbouncer/pgbouncer"])
```

You can also specify a stack:

```
Hatchet::Runner.new("rails3_mri_193", stack: "cedar-14").deploy do |app|
```

## Getting Deploy Output

After Hatchet deploys your app you can get the output by using `app.output`

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  puts app.output
end
```

If you told Hatchet to `allow_failure: true`, then the full output of the failed build will be in `app.output` even though the app was not deployed. It is a good idea to test against the output for text that should be present. Using a testing framework such as `Test::Unit` a failed test output may look like this:

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
  assert_match "Gemfile.lock required", app.output
end
```

Since an error will be raised on failed deploys you don't need to check for a deployed status (the error will automatically fail the test for you).

## Running Processes

Often times asserting output of a build can only get you so far, and you will need to actually run a task on the dyno. To run a non-interactive command such as `heroku run ls`, you can use the `app.run()` command without passing a block:

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  assert_match "applications.css", app.run("ls public/assets")
```

This is useful for checking the existence of generated files such as assets. To run an interactive session such as `heroku run bash` or `heroku run rails console`, run the command and pass a block:

```
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  app.run("cat Procfile")
end
```

By default commands will be shell escaped (to prevent commands from escaping the `heroku run` command), if you want to manage your own quoting you can use the `raw: true` option:

```
app.run('echo \$HELLO \$NAME', raw: true)
```

You can specify Heroku flags to the `heroku run` command by passing in the `heroku:` key along with a hash.

```
app.run("nproc", heroku: { "size" => "performance-l" })
# => 8
```

You can see a list of Heroku flags by running:

```
$ heroku run --help
run a one-off process inside a heroku dyno

USAGE
  $ heroku run

OPTIONS
  -a, --app=app        (required) app to run command against
  -e, --env=env        environment variables to set (use ';' to split multiple vars)
  -r, --remote=remote  git remote of app to use
  -s, --size=size      dyno size
  -x, --exit-code      passthrough the exit code of the remote command
  --no-notify          disables notification when dyno is up (alternatively use HEROKU_NOTIFICATIONS=0)
  --no-tty             force the command to not run in a tty
  --type=type          process type
```

By default Hatchet will set the app name and the exit code


```
app.run("exit 127")
puts $?.exitcode
# => 127
```

To skip a value you can use the constant:

```
app.run("exit 127", heroku: { "exit-code" => Hatchet::App::SkipDefaultOption})
puts $?.exitcode
# => 0
```

To specify a flag that has no value (such as `--no-notify`, `no-tty`, or `--exit-code`) pass a `nil` value:

```
app.run("echo 'foo'", heroku: { "no-notify" => nil })
# This is the same as `heroku run echo 'foo' --no-notify`
```

## Modify Application Files on Disk

While template apps provided from your `hatchet.json` can provide different test cases, you may want to test minor varriations of an app. You can do this by using the `before_deploy` hook to modify files on disk inside of an app in a threadsafe way that will only affect the app's local instance:

```ruby
Hatchet::App.new("default_ruby", before_deploy: { FileUtils.touch("foo.txt")}).deploy do
  # Assert stuff
end
```

After the `before_deploy` block fires, the results will be committed to git automatically before the app deploys.

You can also manually call the `before_deploy` method:

```ruby
app  = Hatchet::App.new("default_ruby")
app.before_deploy do
  FileUtils.touch("foo.txt")
end
app.deploy do
  # Assert stuff
end
```

Note: If you're going to shell out in this `before_deploy` section, you should check the success of your command, for example:

```ruby
before_deploy = Proc.new do
  cmd = "bundle update"
  output = `#{cmd}`
  raise "Command #{cmd.inspect} failed unexpectedly with output: #{output}"
end
Hatchet::App.new("default_ruby", before_deploy: before_deploy).deploy do
  # Assert stuff
end
```

It's helpful to make a helper function in your library if this pattern happens a lot in your app.

## Heroku CI

Hatchet supports testing Heroku CI.

```ruby
Hatchet::Runner.new("rails5_ruby_schema_format").run_ci do |test_run|
  assert_match "Ruby buildpack tests completed successfully", test_run.output

  test_run.run_again # Runs tests again, for example to make sure the cache was used

  assert_match "Using rake", test_run.output
end
```

Call the `run_ci` method on the hatchet `Runner`. The object passed to the block is a `Hatchet::TestRun` object. You can call:

- `test_run.output` will have the setup and test output of your tests.
- `test_run.app` has a reference to the "app" you're testing against, however currently no `heroku create` is run (as it's not needed to run tests, only a pipeline and a blob of code).

An exception will be raised if either the test times out or a status of `:errored` or `:failed` is returned. If you expect your test to fail, you can pass in `allow_failure: true` when creating your hatchet runner. If you do that, you'll also get access to different statuses:

- `test_run.status` will return a symbol of the status of your test. Statuses include, but are not limited to `:pending`, `:building`, `:errored`, `:creating`, `:succeeded`, and `:failed`

You can pass in a different timeout to the `run_ci` method `run_ci(timeout: 300)`.

You probably need an `app.json` in the root directory of the app you're deploying. For example:

```json
{
  "environments": {
    "test": {
      "addons":[
         "heroku-postgresql"
      ]
    }
  }
}
```

This is on [a Rails5 test app](https://github.com/sharpstone/rails5_ruby_schema_format/blob/master/app.json) that needs the database to run.

Do **NOT** specify a `buildpacks` key in the `app.json` because Hatchet will automatically do this for you. If you need to set buildpacks you can pass them into the `buildpacks:` keword argument:

```
buildpacks = []
buildpacks << "https://github.com/heroku/heroku-buildpack-pgbouncer.git"
buildpacks << [HATCHET_BUILDPACK_BASE, HATCHET_BUILDPACK_BRANCH.call].join("#")

Hatchet::Runner.new("rails5_ruby_schema_format", buildpacks: buildpacks).run_ci do |test_run|
  # ...
end
```

## Testing on CI

Once you've got your tests working locally, you'll likely want to get them running on CI. For reference see the [Circle CI config from this repo](https://github.com/heroku/hatchet/blob/master/.circleci/config.yml) and the [Heroku CI config from the ruby buildpack](https://github.com/heroku/heroku-buildpack-ruby/blob/master/app.json).

To make running on CI easier, there is a setup script in Hatchet that can be run before your tests are executed:

```yml
bundle exec hatchet ci:setup
```

If you're a Heroku employee see [private instructions for setting up test users](https://github.com/heroku/languages-team/blob/master/guides/create_test_users_for_ci.md) to generate a user a grab the API token. Once you have an API token you'll want to set up these env vars with your CI provider:

```
HATCHET_APP_LIMIT=100
HATCHET_RETRIES=3
HEROKU_API_KEY=<redacted>
HEROKU_API_USER=<redacted@example.com>
```

## Extra App Commands

```
app.add_database # adds a database to specified app
app.heroku       # returns a Herou Api client https://github.com/heroku/heroku.rb
```

## Hatchet CLI

Hatchet has a CLI for installing and maintaining external repos you're
using to test against. If you have Hatchet installed as a gem run

    $ hatchet --help

For more info on commands. If you're using the source code you can run
the command by going to the source code directory and running:

    $ ./bin/hatchet --help


## License

MIT


