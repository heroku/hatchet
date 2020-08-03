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

Hatchet assumes a test framework doesn't exist. [This project](https://github.com/heroku/hatchet) uses rspec to run it's own tests you can use these as a reference as well as the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby).

Running `focused: true` in rspec allows you to choose which test to run and to tag tests. Rspec has useful plugins, such as `gem 'rspec-retry'` which will re-run any failed tests a given number of times (I recommend setting this to at least 2) to decrease false negatives in your tests.

Whatever testing framework you chose, we recommend using a parallel test runner when running the full suite. [parallel_split_test](https://github.com/grosser/parallel_split_test).

If you're unfamiliar with the ruby testing eco-system or want some help, start by looking at existing projects.

*Spoilers*: There is a section below on getting Hatchet to work on CI

## Quicklinks

- Concepts
  - [Tell Hatchet how to find your buildpack](#specify-buildpack)
  - [Give Hatchet some example apps to deploy](#example-apps)
  - [Use Hatchet to deploy app](#deploying-apps)
  - [Use Hatchet to test runtime behavior and enviornment](#build-versus-run-testing)
  - [How to update or modify test app files safely in parallel](#modifying-apps-on-disk-before-deploy)
  - [Understand how Hatchet (does and does not) clean up apps](#app-reaping)
  - [How to re-deploy the same app](#deploying-multiple-times)
  - [How to test your buildpack on Heroku CI](#testing-ci)
  - [How to safely test locally without modifying disk or your environment](#testing-on-local-disk-without-deploying)
  - [How to set up your buildpack on a Continuous Integration (CI) service](#running-your-buildpack-tests-on-a-ci-service)

- Reference Docs:
  - Method arguments to `Hatchet::Runner.new` [docs](#init-options)
  - Method documentation for `Hatchet::Runner` and `TestRun` objects [docs](#app-methods)
  - All ENV vars and what they do [docs](#env-vars)

- Basic
  - [Introduction to the Rspec testing framework for non-rubyists](#basic-rspec)
  - [Introduction to Ruby for non-rubyists](#basic-ruby)

## Concepts

### Specify buildpack

Tell Hatchet what buildpack you want to use by default by setting environment variables:

```
HATCHET_BUILDPACK_BASE=https://github.com/heroku/heroku-buildpack-nodejs.git
```

You must set this before this code is loaded:

```ruby
require 'hatchet'`
```

If you do not specify `HATCHET_BUILDPACK_URL` the default Ruby buildpack will be used. If you do not specify a `HATCHET_BUILDPACK_BRANCH` the current branch you are on will be used. This is how the Ruby buildpack runs tests on branches on CI (by leaving `HATCHET_BUILDPACK_BRANCH` blank).

The workflow generally looks like this:

1. Make a change to the codebase
2. Commit it and push to GitHub so it's publically available
3. Execute your test suite or individual test
4. Repeat until you're happy

### Example apps:

Hatchet works by deploying example apps to Heroku's production service first you'll need an app to deploy that works with the buildpack you want to test. There are two ways to give Hatchet a test app, you can either specify a remote app or a local directory.

- **Local directory use of hatchet:**

```ruby
Hatchet::Runner.new("path/to/local/directory").deploy do |app|
end
```

An example of this is the [heroku/nodejs buildpack tests](https://github.com/heroku/heroku-buildpack-nodejs/blob/9898b875f45639d9fe0fd6959f42aea5214504db/spec/ci/node_10_spec.rb#L6).

You can either check in your apps or, you can use code to generate them, for example:

- [Generating an example app](https://github.com/sharpstone/force_absolute_paths_buildpack/blob/7f99dc656239e76d8d350f5b0d6d677ca392bc8d/spec/hatchet/buildpack_spec.rb#L5-L20)
- [Source code for `generate_fixture_app`](https://github.com/sharpstone/force_absolute_paths_buildpack/blob/7f99dc656239e76d8d350f5b0d6d677ca392bc8d/spec/spec_helper.rb#L35-L58)

If you generate example apps programatically then add the folder you put them in to your `.gitignore`.

> Note: If you're not using the `hatchet.json` you'll still need an empty one in your project with contents `{}`

- **Github app use of hatchet:**

Instead of storing your apps locally or generating them you can point hatchet at a remote github repo.

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

If you have conflicting names, use full paths like `Hatchet::RUnner.new("sharpstone/no_lockfile")`.

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

If you don't want to lock to a specific commit, you can always use the latest commit by specifying `master` manually as seen above.

### Deploying apps

Once you've got an app and have set up your buildpack you can deploy an app and assert based off of the output (all examples use rspec for testing framework).

```ruby
Hatchet::Runner.new("default_ruby").deploy do |app|
  expect(app.output).to match("Installing dependencies using bundler")
end
```

By default an error will be raised if the deploy doesn't work which forces the test to fail. If you're trying to test failing behavior (for example you want to test that an app without a Gemfile.lock fails to build), you can manually allow failures:

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
  expect(app).not_to be_deployed
  expect(app.output).to include("Gemfile.lock required")
end
```

### Build versus run testing

In addition to testing what the build output was, the next most common thing to assert is that behavior at runtime produces expected results. Hatchet provides a helper for calling `heroku run <cmd>` and asserting against it. For example:

```ruby
Hatchet::Runner.new("minimal_webpacker", buildpacks: buildpacks).deploy do |app, heroku|
  expect(app.run("which node")).to match("/app/bin/node")
end
```

In this example hatchet is calling `heroku run which node` and passing the results back to the test so we can assert against it.

- **Asserting exit status:**

In ruby the way you assert a command you ran on the shell was succesful or not is by using the `$?` "magic object". By default calling `app.run` will set this variable which can be used in your tests:

```ruby
Hatchet::Runner.new("minimal_webpacker", buildpacks: buildpacks).deploy do |app, heroku|
  expect(app.run("which node")).to match("/app/bin/node")
  expect($?.exitstatus).to eq(0)
  expect($?.success?).to be_truthy

  # In Ruby all objects except `nil` and `false` are "truthy" in this case it could also be tested using `be_true` but
  # it's best practice to use this test helper in rspec
end
```

You can disable this behavior [see how to do it in the reference tests](https://github.com/heroku/hatchet/blob/master/spec/hatchet/app_spec.rb)

- **Escaping and raw mode:**

By default `app.run()` will escape the input so you can safely call `app.run("cmd && cmd")` and it works as expected. But if you want to do something custom, you can enable raw mode by passing in `raw: true` [see how to do it in the reference tests](https://github.com/heroku/hatchet/blob/master/spec/hatchet/app_spec.rb)

- **Heroku options:**

You can use all the options available to `heroku run bash` such as `heroku run bash --env FOO=bar` [see how to do it in the reference tests](https://github.com/heroku/hatchet/blob/master/spec/hatchet/app_spec.rb)

### Modifying apps on disk before deploy

Hatchet is designed to play nicely with running tests in parallel via threads or processes. To support this the code that is executed in the `deploy` block is actually being run in a new directory. This allows you to modify files on disk safely without having to worry about race conditions, but it introduces the unexpected behavior that changes might not work like you think they will.

One common pattern is to have a minimal example app and then to modify it as needed before your tests, you can do this safely using the `before_deploy` block.

```ruby
Hatchet::Runner.new("default_ruby").tap do |app|
  app.before_deploy do
    out = `echo 'ruby "2.7.1"'` >> Gemfile
    raise "Echo command failed: #{out}" unless $?.success?
  end
  app.deploy do |app|
    expect(app.output).to include("Using Ruby version: ruby-2.6.6")
  end
end
```

> The [tap method in ruby](https://ruby-doc.org/core-2.4.0/Object.html#method-i-tap) returns itself in a block, it makes this example cleaner but it's not required.

Note that we're checking the status code of the shell command we're running (shell commands are executed via back ticks in ruby), a common pattern is to write a simple helper function to automated this:

```ruby
# spec_helper.rb

def run!(cmd)
  out = `#{cmd}`
  raise "Command #{cmd} failed with output #{out}" unless $?.success?
  out
end
```

Then you can use it in your tests:

```ruby
Hatchet::Runner.new("default_ruby").tap do |app|
  app.before_deploy do
    run!(%Q{echo 'ruby "2.7.1"'})
  end
  app.deploy do |app|
    expect(app.output).to include("Using Ruby version: ruby-2.6.6")
  end
end
```

Note: that `%Q{}` is a method of creating a string in Ruby if we didn't use it here we could escape the quotes:

```ruby
run!("echo 'ruby \"2.7.1\"'")
```

In Ruby double quotes allow for the insert operator in strings, but single quotes do not:

```ruby
name = "schneems"
puts "Hello #{name}"     # => Hello schneems
puts 'Hello #{name}'     # => Hello #{name}
puts "Hello '#{name}'"   # => Hello 'schneems'
puts %Q{Hello "#{name}"} # => Hello "schneems"
```

### App reaping

When your tests are running you'll see hatchet output some details about what it's doing:

```
Hatchet setup: "hatchet-t-bed73940a6" for "rails51_webpacker"
```

And:

```
Destroying "hatchet-t-fd25e3626b". Hatchet app limit: 80
```

By default hatchet does not destroy your app at the end of the test run, that way if your test failed unexpectedly if it's not destroyed yet, you can:


```
$ heroku run bash -a hatchet-t-bed73940a6
```

And use that to debug. Hatchet deletes old apps on demand. You tell it what your limits are and it will stay within those limits:

```
HATCHET_APP_LIMIT=20
```

With these env vars, Hatchet will "reap" older hatchet apps when it sees there are 20 or more hatchet apps. For CI, it's recomment you increase the HATCHET_APP_LIMIT to 80-100. Hatchet will mark apps as safe for deletion once they've finished and the `teardown!` method has been called on them (it tracks this by enabling maintenance mode on apps). Hatchet only tracks its own apps. If your account has reached the maximum number of global Heroku apps, you'll need to manually remove some.

If for some reason an app is not marked as being in maintenance mode it can be deleted, but only after it has been allowed to live for a period of time. This is configured by the `HATCHET_ALIVE_TTL_MINUTES` env var. For example if you set it for `7` then Hatchet will ensure any apps that are not marked as being in maintenace mode are allowed to live for at least seven minutes. This should give the app time to finish execution of the test so it is not deleted mid-deploy. When this deletion happens, you'll see a warning in your output. It could indicate you're not properly cleaning up and calling `teardown!` on some of your apps, or it could mean that you're attempting to execute more tests concurrently than your `HATCHET_APP_LIMIT` allows. This might happen if you have multiple CI runs executing at the same time.

It's recommend you don't use your personal Heroku API key for running tests on a CI server since the hatchet apps count against your account maximum limits. Running tests using your account locally is fine for debugging one or two tests.

If you find your local account has hit your maximum app limit, one handy trick is to get rid of any old "default" heroku apps you've created. This plugin (https://github.com/hunterloftis/heroku-destroy-temp) can help:

```
$ heroku plugins:install heroku-destroy-temp
$ heroku apps:destroy-temp
```

> This won't detect hatchet apps, but it's still handy for cleaning up other unused apps.

### Deploying multiple times

If your buildpack uses the cache, you'll likely want to deploy multiple times against the same app. Here's an example of how to do that:

```ruby
Hatchet::Runner.new("python_default").deploy do |app|
  expect(app.output).to match(/Installing pip/)

  # Redeploy with changed requirements file
  run!(%Q{echo "pygments" >> requirements.txt})
  app.commit!

  app.push! # <======= HERE

  expect(app.output).to match("Requirements file has been changed, clearing cached dependencies")
end
```

### Testing CI

You can run an app against CI using the `run_ci` command (instead of `deploy`). You can re-run tests against the same app with the `run_again` command.

```ruby
Hatchet::Runner.new("python_default").run_ci do |test_run|
  expect(test_run.output).to match("Downloading nose")
  expect(test_run.status).to eq(:succeeded)

  test_run.run_again

  expect(test_run.output).to match("installing from cache")
  expect(test_run.output).to_not match("Downloading nose")
end
```

> Note: That the thing returned by the `run_ci` command is not an "app" object but rather a `test_run` object.

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

```ruby
buildpacks = [
  "https://github.com/heroku/heroku-buildpack-pgbouncer.git",
  :default
]

Hatchet::Runner.new("rails5_ruby_schema_format", buildpacks: buildpacks).run_ci do |test_run|
  # ...
end
```

> Note that the `:default` symbol (like a singleton string object in Ruby) can be used for where you want your buildpack inserted, it will be replaced with your app's repo and git branch you're testing against.

### Testing on local disk without deploying

Sometimes you might want to assert something against a test app without deploying. This is tricky if you're modifying files or the environment in your test. To help out there's a helper `in_directory_fork`:

```ruby
Hatchet::App.new('rails6-basic').in_directory_fork do
  require 'language_pack/rails5'
  require 'language_pack/rails6'

  expect(LanguagePack::Rails5.use?).to eq(false)
  expect(LanguagePack::Rails6.use?).to eq(true)
end
```

## Running your buildpack tests on a CI service

Once you've got your tests working locally, you'll likely want to get them running on CI. For reference see the [Circle CI config from this repo](https://github.com/heroku/hatchet/blob/master/.circleci/config.yml) and the [Heroku CI config from the ruby buildpack](https://github.com/heroku/heroku-buildpack-ruby/blob/master/app.json).

To make running on CI easier, there is a setup script in Hatchet that can be run on your CI server each time before your tests are executed:

```yml
bundle exec hatchet ci:setup
```

If you're a Heroku employee see [private instructions for setting up test users](https://github.com/heroku/languages-team/blob/master/guides/create_test_users_for_ci.md) to generate a user a grab the API token.

Once you have an API token you'll want to set up these env vars with your CI provider:

```
HATCHET_APP_LIMIT=100
HATCHET_RETRIES=2
HEROKU_API_KEY=<redacted>
HEROKU_API_USER=<redacted@example.com>
```

You can refernce this PR for getting a buildpack set up from scratch with tests to see what kinds of files you might need: https://github.com/sharpstone/force_absolute_paths_buildpack/pull/2

## Reference docs

The `Hatchet::Runner.new` takes several arguments.

### Init options

- stack (String): The stack you want to deploy to on Heroku.

```ruby
Hatchet::Runner.new("default_ruby", stack: "heroku-16").deploy do |app|
  # ...
end
```

- name (String): The name of an app you want to use. If you choose to provide your own app name, then hatchet will not reap it, you'll have to manually delete it.

- allow_failure (Boolean): If set to a truthy value then the test won't error if the deploy fails
- labs (Array): Heroku has "labs" that are essentially features that are not enabled by default, one of the most popular ones is "preboot" https://devcenter.heroku.com/articles/preboot.
- buildpacks (Array):  Pass in the buildpacks you want to use against your app

```ruby
Hatchet::Runner.new("default_ruby", buildpacks: ["heroku/nodejs", :default]).deploy do |app|
  # ...
end
```

In this example the app would use the nodejs buildpack and then `:default` gets replaced by your Git url and branch name.

- before_deploy (Block): Instead of using the `tap` syntax you can provide a block directly to hatchet app initialization:

```ruby
Hatchet::Runner.new("default_ruby", before_deploy: ->{ FileUtils.touch("foo.txt")}).deploy do
  # Assert stuff
end
```

A block in ruby is essentially an un-named method. Think of it as code to be executed later. See docs below for more info on blocks, procs and lambdas.

- config (Hash): You can set config vars against your app:

```ruby
config = { "DEPLOY_TASKS" => "run:bloop", "FOO" => "bar" }
Hatchet::Runner.new('default_ruby', config: config).deploy do |app|
  expect(app.run("echo $DEPLOY_TASKS").to match("run:bloop")
end
```

> A hash in Ruby is like a dict in python. It is a set of key/value pairs. The syntax `=>` is called a "hashrocket" and is an alternative syntax to "json" syntax for hashes. It is used to allow for string keys instead of symbol keys.

### App methods:

- `app.set_config()`: Updates the configuration on your app taking in a hash

You can also update your config using the `set_config` method:

```ruby
app = Hatchet::Runner.new("default_ruby")
app.set_config({"DEPLOY_TASKS" => "run:bloop", "FOO" => "bar"})
app.deploy do
  expect(app.run("echo $DEPLOY_TASKS").to match("run:bloop")
end
```

- `app.get_config()`: returns the Heroku value for a specific env var:

```ruby
app = Hatchet::Runner.new("default_ruby")
app.set_config({"DEPLOY_TASKS" => "run:bloop", "FOO" => "bar"})
app.get_config("DEPLOY_TASKS") # => "run:bloop"
```

- `app.set_lab()`: Enables the specified lab/feature on the app
- `app.add_database()`: adds a database to the app, defaults to the "dev" command
- `app.run()`: Runs a `heroku run bash` session with the arguments, covered above.
- `app.create_app`: Can be uused to manually create the app without deploying it (You probably want `setup!` though)
- `app.setup!`: Gets the application in a state ready for deploy.
  - Creates the Heroku app
  - Sets up any specified labs (from initialization)
  - Sets up any specified buildpacks
  - Sets up specified config
  - Calls the contents of the `before_deploy` block
- `app.before_deploy`: Allows you to update the `before_deploy` block

```ruby
app = Hatchet::Runner.new("default_ruby")
app.before_deploy do
  FileUtils.touch("foo.txt")
end
```

Is the same as:

```ruby
before_deploy_proc = Proc.new do
  FileUtils.touch("foo.txt")
end

app = Hatchet::Runner.new("default_ruby", before_deploy: before_deploy_proc)
app.setup!
```


- `app.commit!`: Will updates the contents of your local git dir if you've modified files on disk

```ruby
Hatchet::Runner.new("python_default").deploy do |app|
  expect(app.output).to match(/Installing pip/)

  # Redeploy with changed requirements file
  run!(%Q{echo "" >> requirements.txt})
  run!(%Q{echo "pygments" >> requirements.txt})

  app.commit! # <=== Here

  app.push!
end
```

> Note: Any changes to disk from a `before_deploy` block will be committed automatically after the block executes


- `app.in_directory`: Runs the given block in a temp directory (but in the same process). One advanced debugging technique is indefinetly pause test execution after outputting the directory so you can `cd` there and manually debug:

```ruby
Hatchet::Runner.new("python_default").in_directory do |app|
  puts "Temp dir is: #{Dir.pwd}"
  STDIN.gets("foo") # <==== Pauses tests until stdin receives "foo"
end
```

> Note: If you want to execute tests in this temp directory, you likely want to use `in_directory_fork` otherwise you might accidentally contaminate the current environment's variables if you modify them.

- `app.in_directory_fork`: Runs the given block in a temp directory and inside of a forked process
- `app.directory`: Returns the current temp directory the appp is in.
- `app.deploy`: Your main method, takes a block to execute after the deploy is successful. If no block is provided you must manually call `app.teardown!` (see below for an example).
- `app.output`: The output contents of the deploy
- `app.platform_api`: Returns an instance of the [platform-api Heroku client](https://github.com/heroku/platform-api). If hatchet doesn't give you access to a part of Heroku that you need, you can likely do it with the platform-api client.
- `app.push!`: Push code to your heroku app. Can be used inside of a `deploy` block to re-deploy.
- `app.run_ci`: Runs Heroku CI against the app, returns a TestRun object in the block
- `app.teardown!`: This method is called automatically when using `app.deploy` in block mode after the deploy block finishes. When called it will clean up resources, mark the app as being finished (by setting {maintenance" => true} on the app) so that the reaper knows it is safe to delete later. Here is an example of a test that creates and deploys an app manually, then later tears it down manually. If you deploy an application without calling `teardown!` then Hatchet will not know it is safe to delete and may keep it around for much longer than required for the test to finish.

```ruby
before(:all) do
  @app = Hatchet::Runner.new("default_ruby")
  @app.deploy
end

after(:all) do
  @app.teardown! if @app
end

it "uses ruby" do
  expect(@app.run("ruby -v")).to match("ruby")
end

```
- `test_run.run_again`: Runs the app again in Heroku CI
- `test_run.status`: Returns the status of the CI run (possible values are `:pending`, `:building`, `:creating`, `:succeeded`, `:failed`, `:errored`)
- `test_run.output`: The output of a given test run

### ENV vars

```sh
HATCHET_BUILDPACK_BASE=https://github.com/heroku/heroku-buildpack-nodejs.git
HATCHET_BUILDPACK_BRANCH=<branch name if you dont want hatchet to set it for you>
HATCHET_RETRIES=2
HATCHET_APP_LIMIT=(set to something low like 20 locally, set higher like 80-100 on CI)
HEROKU_API_KEY=<redacted>
HEROKU_API_USER=<redacted@redacted.com>
HATCHET_ALIVE_TTL_MINUTES=7
```

> The syntax to set an env var in Ruby is `ENV["HATCHET_RETRIES"] = "2"` all env vars are strings.

- `HATCHET_BUILDPACK_BASE`: This is the URL where hatchet can find your buildpack. It must be public for Heroku to be able to use your buildpack.
- `HATCHET_BUILDPACK_BRANCH`: By default Hatchet will use your current git branch name. If for some reason git is not available or you want to manually specify it like `ENV["HATCHET_BUILDPACK_BRANCH'] = ENV[`MY_CI_BRANCH`]` then you can.
- `HATCHET_RETRIES` If the `ENV['HATCHET_RETRIES']` is set to a number, deploys are expected to work and automatically retry that number of times. Due to testing using a network and random failures, setting this value to `3` retries seems to work well. If an app cannot be deployed within its allotted number of retries, an error will be raised. The downside of a larger number is that your suite will keep running for much longer when there are legitimate failures.
- `HATCHET_APP_LIMIT`: The maximum number of **hatchet** apps that hatchet will allow in the given account before running the reaper. For local execution keep this low as you don't want your account dominated by hatchet apps. For CI you want it to be much larger, 80-100 since it's not competiting with non-hatchet apps. Your test runner account needs to be a dedicated account.
- `HEROKU_API_KEY`: The api key of your test account user. If you run locally without this set it will use your personal credentials.
- `HEROKU_API_USER`: The email address of your user account. If you run locally without this set it will use your personal credentials.
- `HATCHET_ALIVE_TTL_MINUTES`: The minimum time that hatchet appplications must be allowed to live on a given account if they're not marked by being in maintenance mode. For example if you set this value to 3 it guarantees that a Hatchet app will be allowed to live 3 minutes before Hatchet will try to delete it. Default is 7 minutes. Set to zero to disable.

## Basic

### Basic rspec

Rspec is a testing framework for Ruby. It allows you to "describe" your tests using strings and blocks. This section is intended to be a breif introduction and include a few pitfalls but is not comprehensive.

In your directory rspec assumes a `spec/` folder. It's common to have a `spec_helper.rb` in the root of that folder:

- **spec/spec_helper.rb**

Here's an example of a `spec_helper.rb`: https://github.com/sharpstone/force_absolute_paths_buildpack/blob/master/spec/spec_helper.rb

In this file you'll require files you need to setup the project, you can also set environment variables like `ENV["HATCHET_BUILDPACK_BASE"]`. You can use it to configure your app. Any methods you define in this file will be available to your tests. For example:

```ruby
def run!(cmd)
  out = `#{cmd}`
  raise "Error running #{cmd}, output: #{out}" unless $?.success?
  out
end
```

- **spec/hatchet/buildpack_spec.rb**

Rspec knows a file is a test file or not by the name. It looks for files that end in `spec.rb` you can have as many as you want. I recommend putting them in a "spec/hatchet" sub-folder.

- **File contents**

In rspec you can group several tests under a "description" using `Rspec.describe`. Here's an example: https://github.com/sharpstone/force_absolute_paths_buildpack/blob/master/spec/hatchet/buildpack_spec.rb

An empty example of `spec/hatchet/buildpack_spec.rb` would look like this:

```ruby
require_relative "../spec_helper.rb"

RSpec.describe "This buildpack" do
  it "accepts absolute paths at build and runtime" do
    # expect(true).to eq(true)
  end
end
```

Each `it` block represents a test case. If you ever get an error about no method `expect` it might be that you've forgotten to put your test case inside of a "describe" block.

- **expect syntax**

Once inside of a test, you can assert an expected value against an actual value:

```ruby
value = true
expect(value).to eq(true)
```

This might look like a weird syntax but it's valid ruby. It's shorthand for this:

```ruby
expect(value).to(eq(true))
```

Where `eq` is a method.

If you want to assert the opposite you can use `to_not`:


```ruby
expect(value).to_not eq(false)
```

- **matcher syntax**

In the above example the `eq` is called a "matcher". You're matching it against an object. In this case you're looking for equality `==`.

There are other matchers: https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers

```ruby
expect(value).to be_truthy

value = "hello there"
expect(value).to include("there")
```

Rspec uses some "magic" to convert anything you pass to

Since most values in hatchet are strings, the ones I use the most are:

- Rspec matchers
  - include https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers/include-matcher#string-usage
  - match https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers/match-matcher

Generally I use include when I know the exact value I want to assert against, I use match when there are dynamic values and I want to be able to use a regular expression.

For building regular expressions I like to use the tool https://rubular.com/ for developing and testing regular expressions. Ruby's regular expression engine is very powerful.

- **Keep it simple**

Rspec is a massive library with a host of features. It's possible to quickly make your tests unmaintainable and unreadable in the efforts to keep your code [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). I recommend sticking to only the features mentioned here at first before trying to do anything fancy.

- **What to test**

Here's a PR with a description of several common failure modes that lots of buildpacks should be aware of along with reference implementations:

https://github.com/heroku/heroku-buildpack-python/pull/969

### Basic Ruby

If you're not a Ruby specialist, not to worry. Here's a few things you migth want to do:

- **Write a file and manipulate disk**

```ruby
File.open("facts.txt", "w+") do |f|
  f.write("equal does not mean equitable")
end
```

The first argument is the file name, and the second is the object "mode", here `"w+"` means open for writing and create the file if it doesn't exist. If you want to append to a file instead you can use the mode `"a"`.

The file name can be a relative or absolute path. My personal favorite though is using the Pathname class to represent files on disk [ruby Pathname api docs](https://ruby-doc.org/stdlib-2.7.1/libdoc/pathname/rdoc/Pathname.html). You can also use a pathname object to write and manipulate the disk directly:

```ruby
require 'pathname'
Pathname.new("facts.txt").write("equal does not mean equitable")
```

- API docs:
  - [File](https://ruby-doc.org/core-2.7.0/File.html)
  - [FileUtils](https://ruby-doc.org/stdlib-2.7.1/libdoc/fileutils/rdoc/FileUtils.html)
  - [Pathname](https://ruby-doc.org/stdlib-2.7.1/libdoc/pathname/rdoc/Pathname.html)
  - [Dir](https://ruby-doc.org/core-2.7.1/Dir.html)

- **HEREDOC**

You can define a multi line string in Ruby using `<<~EOM` with a closing `EOM`. Technically `EOM` can be any string, but you're not here for technicalities.

```ruby
File.open("bin/yarn", "w") do |f|
  f.write <<~EOM
    #! /usr/bin/env bash

    echo "Called bin/yarn binstub"
    `yarn install`
  EOM
end
```

This version of heredoc will strip out indentation:

```ruby
puts <<~EOM
           # Notice that the spaces are stripped out of the front of this string
EOM
# => "# Notice that the spaces are stripped out of the front of this string"
```

The `~` Is usually the operator for a heredoc that you want, it's supported in Ruby 2.5+.

- **Hashes**

a hash is like a dict in python. Docs: https://ruby-doc.org/core-2.7.1/Hash.html

```ruby
person_hash = { "name" => "schneems", "level" => 6 }
puts person_hash["name"]
# => "schneems"
```

You can also mutate a hash:

```ruby
person_hash = { "name" => "schneems", "level" => 6 }
person_hash["name"] = "Richard"
puts person_hash["name"]
# => "Richard"
```

You can inspect full objects by calling `inspect` on them:

```ruby
puts person_hash.inspect
# => {"name"=>"schneems", "level"=>6}
```

As an implementation detail note that hashes are ordered

- **ENV**

You can access the current processes' environment variables as a hash using the ENV object:

```ruby
ENV["MY_CUSTOM_ENV_VAR"] = "blm"
puts `echo $MY_CUSTOM_ENV_VAR`.upcase
# => BLM
```

all values must be a string. See the Hash docs for more information on manipulating hashes https://ruby-doc.org/core-2.7.1/Hash.html. Also see the current ENV docs https://ruby-doc.org/core-2.7.1/ENV.html.

- **Strings versus symbols**

In Ruby you can have a define a symobl `:thing` as well as a `"string"`. They look and behave very closely but are different. A symbol is a singleton object, while the string is unique object. One really confusing thing is you can have a hash with both string and symbol keys:

```ruby
my_hash = {}
my_hash["dog"] = "cinco"
my_hash[:dog] = "river"
puts my_hash.inspect
# => {"dog"=>"cinco", :dog=>"river"}
```

- **Blocks, procs, and lambdas**

Blocks are a concept in Ruby for closure. Depending on how it's used it can be an anonomous method. It's always a method for passing around code. When you see `do |app|` that's the beginning of an implicit block. In addition to an implicit block you can create an explicit block using lambdas and procs. In hatchet, these are most likely to be used to update the app `before_deploy`. Here's an example of some syntax for creating various blocks.

```ruby
before_deploy = -> { FileUtils.touch("foo.txt") } # This syntax is called a "stabby lambda"
before_deploy = lambda { FileUtils.touch("foo.txt") } # This is a more verbose lambda
before_deploy = lambda do
  FileUtils.touch("foo.txt") # Multi-line lambda
end
before_deploy = Proc.new { FileUtils.touch("foo.txt") } # A proc and lambda are subtly different, it won't matter to you though
before_deploy = Proc.new do
  FileUtils.touch("foo.txt") # Multi-line proc
end
```

All of these things do the same thing more-or-less. You can execute the code inside by running:

```
before_deploy.call
```

- **Parens**

You might have noticed that some ruby methods use parens and some don't. I.e. `puts "yo"` versus `puts("yo")`. If the parser can determine your intent then you don't have to use parens.

- **Debugging**

If you're not used to debugging Ruby you can reference the [Ruby debugging magic cheat sheet](https://www.schneems.com/2016/01/25/ruby-debugging-magic-cheat-sheet.html). The Ruby language is very powerful in it's ability to [reflect on itself](https://en.wikipedia.org/wiki/Reflection_%28computer_programming%29). Essentially the Ruby code is able to introspect iself to tell you what it's doin. If you're ever lost, ask your ruby code. It might confuse you, but it won't lie to you.

Another good debugging tool is the [Pry debugger and repl](https://github.com/pry/pry).

- **Common Ruby errors**

```
SyntaxError ((irb):14: syntax error, unexpected `end')
```

If you see this, it likely means you forgot a `do` on a block, for example `.deploy |app|` instead of `.deploy do |app|`.

```
NoMethodError (undefined method `upcase' for nil:NilClass)
```

If you see this it means a variable you're using is `nil` unexpectedly. You'll need to use the above debugging techniques to figure out why.

- **More**

Ruby is full of multitudes, this isn't even close to being exhaustive, just enough to make you dangerous and write a few tests. It's infanetly useful for testing, writing CLIs and web apps.

## Hatchet CLI

Hatchet has a CLI for installing and maintaining external repos you're
using to test against. If you have Hatchet installed as a gem run

    $ hatchet --help

For more info on commands. If you're using the source code you can run
the command by going to the source code directory and running:

    $ ./bin/hatchet --help

## License

MIT
