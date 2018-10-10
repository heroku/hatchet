# Hatchet

![](http://f.cl.ly/items/2M2O2Q2I2x0e1M1P2936/Screen%20Shot%202013-01-06%20at%209.59.38%20PM.png)

Hatchet is a an integration testing library for developing Heroku buildpacks.

[![Build Status](https://travis-ci.org/heroku/hatchet.svg?branch=master)](https://travis-ci.org/heroku/hatchet)

## Install

First run:

    $ bundle install

This library uses the heroku CLI and API, you will need to make your API key
available to the system. If you're running on a CI platform you'll need to generate an OAuth token and make it available on the system you're running on.

To get a token, first install the https://github.com/heroku/heroku-cli-oauth#creating plugin, then you can get your token by running:

```sh
$ heroku authorizations:create --description "For Travis"
Creating OAuth Authorization... done
Client:      <none>
ID:          <id value>
Description: For Travis
Scope:       global
Token:      <token>
```

You'll set the `<token>` value to the `HEROKU_API_KEY` env var. For example on Travis you could add it like this:

```sh
$ travis encrypt HEROKU_API_KEY=<token> --add
```

You'll also need an email address that goes with your token:

```sh
$ travis encrypt HEROKU_API_USER=<example@example.com> --add
```

If you're running locally, your system credentials will be pulled from `heroku auth:token`

You'll also need to trigger a "setup" step for CI tasks. You can do it on Travis CI like this:

```
# .travis.yml
before_script: bundle exec hatchet ci:setup
```

and on Heroku CI like this:

```json
{
  "environments": {
    "test": {
      "scripts": {
        "test-setup": "bundle exec hatchet ci:setup",
      }
    }
  }
}
```

## Run the Tests

    $ bundle exec rake test

## Why Test a Buildpack?

To prevent regressions and to make pushing out new features faster and easier.

## What can Hatchet Test?

Hatchet can easily test deployment of buildpacks, getting the build output, and running arbitrary interactive processes such as `heroku run bash`. It can also test running CI against an app.

## Writing Tests

Hatchet is test framework agnostic. [This project](https://github.com/heroku/hatchet) uses `Test::Unit` to run it's own tests. While the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby) uses rspec.

Rspec has a number of advantages, the ability to run `focused: true` to only run the exact test you want as well as the ability to tag tests. Rspec also has a number of useful plugins, one especialy useful one is `gem 'rspec-retry'` which will re-run any failed tests a given number of times (I recommend setting this to at least 2) this decrease the number of false negatives your tests will have.

Whatever testing framework you chose, we recommend using a parallel test runner when running the full suite [parallel_tests](https://github.com/grosser/parallel_tests) works with rspec and test::unit and is amazing.

If you're unfamiliar with the ruby testing eco-system or want some help, looking at existing projects is a good place to get started.

There is a section below on getting Hatchet to work on Travis.

## Testing a Buildpack

Hatchet was built for testing the Ruby buildpack, but you can use it to test any buildpack you desire provided you don't mind writing your tests written in Ruby.

You will need copies of applications that can be deployed by your buildpack. You can see the ones for the Hatchet unit tests (and the Ruby buildpack) https://github.com/sharpstone. Hatchet does not require that you keep these apps checked into your git repo which would make fetching your buildpack slow, instead declare them in a `hatchet.json` file (see below).

Hatchet will automate retrieving these files `$ hatchet install`, as well as deploying them using your local copy of the buildpack, retrieving the build output and running commands against deploying applications.


## Hatchet.json

Hatchet expects a json file in the root of your buildpack called `hatchet.json`. You can configure install options using the `"hatchet"` key. In this example we're telling hatchet to install the given repos to our `test/fixtures` directory instead of the default current directory.

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

Now in your test you can reference one of these applications by using it's git name:

```ruby
Hatchet::Runner.new('no_lockfile')
```

If you have conflicting names, use full paths.

A word of warning on including repos inside of your test
directory, if you're using a runner that looks for patterns such as
`*_test.rb` to run your hatchet tests, it may incorrectly think you want
to run the tests inside of the repos. To get rid of this
problem move your repos direcory out of `test/` or be more specific
with your tests such as moving them to a `test/hatchet` directory and
changing your pattern if you are using `Rake::TestTask` it might look like this:

    t.pattern = 'test/hatchet/**/*_test.rb'

A note on external repos: since you're basing tests on these repos, it
is in your best interest to not change them or your tests may
spontaneously fail. In the future we may create a hatchet.lockfile or
something to declare the commit


## Deploying apps


You can specify the location of your public buildpack url in an environment variable:

```sh
HATCHET_BUILDPACK_BASE=https://github.com/heroku/heroku-buildpack-ruby.git
HATCHET_BUILDPACK_BRANCH=master
```

If you do not specify `HATCHET_BUILDPACK_URL` the default Ruby buildpack will be used. If you do not specify a `HATCHET_BUILDPACK_BRANCH` the current branch you are on will be used. This is how the Ruby buildpack runs tests on branches on travis (by leaving `HATCHET_BUILDPACK_BRANCH` blank).

Deploys are expected to work, if the `ENV['HATCHET_RETRIES']` is set, then deploys will be automatically retried that number of times. Due to testing using a network and random failures, setting this value to `3` retries seems to work well. If an app cannot be deployed within its allotted number of retries an error will be raised.

If you are testing an app that is supposed to fail deployment you can set the `allow_failure: true` flag when creating the app:

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
```

After the block finishes your app will be queued to be removed from heroku. If you are investigating a deploy, you can add the `debug: true` flag to your app:

```ruby
Hatchet::Runner.new("rails3_mri_193", debug: true).deploy do |app|
```

Now after Hatchet is done deploying your app it will remain on Heroku. It will also output the name of the app into your test logs so that you can `heroku run bash` into it for detailed postmortem.

If you are wanting to run a test against a specific app without deploying to it, you can set the app name like this:

```ruby
app = Hatchet::Runner.new("rails3_mri_193", name: "testapp")
```

Deploying the app takes a few minutes, so you may want to skip that part to make debugging a problem easier since you're iterating much faster.

If you need to deploy using a different buildpack you can specify one manually:

```ruby

def test_deploy
  Hatchet::Runner.new("rails3_mri_193", buildpack: "https://github.com/heroku/heroku-buildpack-ruby.git").deploy do |app|
  # ...
```

You can specify multiple buildpacks by passing in an Array.

You can use `Hatchet::App.default_buildpack` to get the buildpack URL and branch specified by environment variables:

```
Hatchet::Runner.new("default_ruby", buildpacks: [Hatchet::App.default_buildpack, "https://github.com/pgbouncer/pgbouncer"])
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

If you told Hatchet to `allow_failure: true` then the full output of the failed build will be in `app.output` even though the app was not deployed. It is a good idea to test against the output for text that should be present. Using a testing framework such as `Test::Unit` a failed test output may look like this

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
  assert_match "Gemfile.lock required", app.output
end
```

Since an error will be raised on failed deploys you don't need to check for a deployed status (the error will automatically fail the test for you).

## Running Processes

Often times asserting output of a build can only get you so far, and you will need to actually run a task on the dyno. To run a non-interactive command such as `heroku run ls` you can do this using the `app.run()` command and do not pass it a block

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  assert_match "applications.css", app.run("ls public/assets")
```

This is useful for checking the existence of generated files such as assets. If you need to run an interactive session such as `heroku run bash` or `heroku run rails console` you can use the run command and pass a block:

```
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  app.run("cat Procfile")
end
```

This is the prefered way to run commands against the app. You can also string together commands in a session, however due to difficulties in driving a REPL programatically via [repl_runner](http://github.com/schneems/repl_runner) it's less deterministic.


```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  app.run("bash") do |bash|
    bash.run("ls")           {|result| assert_match "Gemfile.lock", result }
    bash.run("cat Procfile") {|result| assert_match "web:", result }
  end
end
```

Please read the docs on [repl_runner](http://github.com/schneems/repl_runner) for more info. The only interactive commands that are supported out of the box are `rails console`, `bash`, and `irb` it is fairly easy to add your own though:

## Heroku CI

Hatchet supports testing Heroku CI.

```ruby
Hatchet::Runner.new("rails5_ruby_schema_format").run_ci do |test_run|
  assert_match "Ruby buildpack tests completed successfully", test_run.output
end
```

Call the `run_ci` method on the hatchet `Runner`. The object passed to the block is a `Hatchet::TestRun` object. You can call:

- `test_run.output` this will have the setup and test output of your tests.
- `test_run.app` this has a reference to the "app" you're testing against, however currently no `heroku create` is run (as it's not needed to run tests, only a pipeline and a blob of code).

An exception will be raised if either the test times out or a status of `:errored` or `:failed` is returned. If you expect your test to fail, you can pass in `allow_failure: true` when creating your hatchet runner. If you do that, you'll also get access to different statuses:

- `test_run.status` this will return a symbol of the status of your test. Statuses include, but are not limited to `:pending`, `:building`, `:errored`, `:creating`, `:succeeded`, and `:failed`

You can pass in a different timeout to the `run_ci` method `run_ci(timeout: 300)`.

You will likely need an `app.json` in the root directory of the app you're deploying. For example:

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

Do **NOT** specify a `buildpacks` key in the `app.json` as Hatchet will do this for you automatically. If you need to set buildpacks you can pass them into the `buildpacks:` keword argument:

```
buildpacks = []
buildpacks << "https://github.com/heroku/heroku-buildpack-pgbouncer.git"
buildpacks << [HATCHET_BUILDPACK_BASE, HATCHET_BUILDPACK_BRANCH.call].join("#")

Hatchet::Runner.new("rails5_ruby_schema_format", buildpacks: buildpacks).run_ci do |test_run|
  # ...
end
```

## Testing on Travis

Once you've got your tests working locally, you'll likely want to get them running on Travis because a) CI is awesome, and b) you can use pull requests to run your all your tests in parallel without having to kill your network connection.

You will want to set the `HATCHET_DEPLOY_STRATEGY` to `git`.

To run on travis you will need to configure your `.travis.yml` to run the appropriate commands and to set up encrypted data so you can run tests against a valid heroku user.

For reference see the `.travis.yml` from [hatchet](https://github.com/heroku/hatchet/blob/master/.travis.yml) and the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby/blob/master/.travis.yml). To make running on travis easier there is a rake task in Hatchet that can be run before your tests are executed

```
before_script: bundle exec hatchet ci:setup
```

I recommend signing up for a new heroku account for running your tests on travis, otherwise you will quickly excede your API limit. Once you have the new api token you can use this technique to [securely send travis the data](http://docs.travis-ci.com/user/environment-variables/#Secure-Variables).


```
$ travis encrypt HEROKU_API_KEY=<token> --add
```

You'll also need to download the Heroku CLI. Add the executable `etc/ci_setup.sh` to your project, with contents:

```
#!/usr/bin/env bash

sudo apt-get -qq update
sudo apt-get install software-properties-common
curl --fail --retry 3 --retry-delay 1 --connect-timeout 3 --max-time 30 https://cli-assets.heroku.com/install-ubuntu.sh | sh
```

Be sure to change the file permissions with `chmod u+x etc/ci_setup.sh` so that the file is executable.

To run this and download the Heroku cli, you will need to add this step before your install or script depending on your Travis setup process.

```
before_script:
  - bash etc/ci_setup.sh
```

If your Travis tests are containerized, you may need sudo to complete this successfully. In that case, you'll need to add the following:

```
sudo: required
before_install:
  - sudo bash etc/ci_setup.sh
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


