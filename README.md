# Hatchet

![](http://f.cl.ly/items/2M2O2Q2I2x0e1M1P2936/Screen%20Shot%202013-01-06%20at%209.59.38%20PM.png)

Hatchet is an integration testing library for developing Heroku buildpacks.

## Install

To get started, add this gem to your Gemfile:

```
gem "heroku_hatchet"
```

Then run:

```
$ bundle install
```

This library uses the Heroku CLI and API. You will need to make your API key available to the system (`$ heroku login`). If you're running on a CI platform, you'll need to generate an OAuth token and make it available on the system you're running on see the "CI" section below.

## About Hatchet

### Why Test a Buildpack?

Testing a buildpack prevents regressions, and pushes out new features faster and easier.

### What can Hatchet test?

Hatchet can easily test certain operations: deployment of buildpacks, getting the build output and running arbitrary interactive processes (e.g. `heroku run bash`). Hatchet can also test running Heroku CI against an app.

### How does Hatchet test a buildpack?

To be able to check the behavior of a buildpack, you have to execute it. Hatchet does this by creating new Heroku apps `heroku create`, setting them to use your branch of the buildpack (must be available publicly) `heroku buildpacks:set https://github.com/your/buildpack-url#branch-name`, then deploying the app `git push heroku master`. It has built-in features such as API rate throttling (so your deploys slow down instead of fail) and internal retry mechanisms. Once deployed, it can `heroku run <command>` for you to allow you to assert behavior.

### Can I use Hatchet to test my buildpack locally?

Yes, but the workflow is less than ideal since Heroku (and by extension, Hatchet) need your work to be available at a public URL. Let's say you're doing TDD and have already written a single failing test. You are developing on a branch and have already committed the test to that branch. To test your new code, you'll need to commit what you've got, push it to your public source repository.

```
$ git add -P
$ git commit -m "[ci skip] WIP"
$ git push origin <current-branchname>
$ bundle exec rspec spec/path-to-your-test.rb:5 # This syntax focus runs a single test on line number 5
```

Now when the tests execute Hatchet will use your code on your public branch. If you don't like a bunch of ugly "wip" commits you can keep amending the same commit over and over while you're iterating, alternatively you can [rebase your commits when you're done](https://www.codetriage.com/rebase).

### Isn't deploying an app to Heroku overkill for testing? I want to go faster.

Hatchet is for integration testing. You can also unit test your code if you want your tests to execute much quicker. If your buildpack is written in bash, there is [shUnit2](https://github.com/kward/shunit2/), for example. It is recommended that you use both integration and unit tests.

But can't you integration test the buildpack by calling `bin/compile` directly without having to jump through deploying a Heroku app? It is possible to call your `bin/compile` script from your machine locally without Hatchet, but you'll not have access to config vars, addons, release phase, `heroku run`, and many more features. Also, calling `bin/compile` is very slow, and a medium to large buildpack can have upwards of 70 different integration test cases. If each were to take 1 minute optimistically, it would take over an hour to run your whole suite. Since Hatchet can be safely run via a parallel runner, it can execute most of these builds in parallel, and the whole suite would take roughly 5 minutes when running on CI.

In addition to speed, Hatchet provides isolation. Suppose you're executing `bin/compile` locally. In that case, you need to be very careful not to pollute the environment or local disk between runs, or you'll end up with odd failures that are seemingly impossible to hunt down.

## Quicklinks

- Getting started
  - [Add hatchet tests to a existing buildpack](#hatchet-init)
- Concepts
  - [Tell Hatchet how to find your buildpack](#specify-buildpack)
  - [Give Hatchet some example apps to deploy](#example-apps)
  - [Use Hatchet to deploy app](#deploying-apps)
  - [Use Hatchet to test runtime behavior and environment](#build-versus-run-testing)
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

- Ruby language and ecosystem basics
  - [Introduction to the Rspec testing framework for non-rubyists](#basic-rspec)
  - [Introduction to Ruby for non-rubyists](#basic-ruby)

## Getting Started

### Hatchet Init

If you're working in a project that does not already have hatchet tests you can run this command to get started quickly:

Make sure you're in directory that contains your buildpack and run:

```
$ gem install heroku_hatchet
$ hatchet init
```

This will bootstrap your project with the necessarry files to test your buildpack. Including but not limited to:

- Gemfile
- hatchet.json
- spec/spec_helper.rb
- spec/hatchet/buildpack_spec.rb
- .circleci/config.yml
- .github/dependabot.yml
- .gitignore

Once this executes successfully then you can run your tests with:

```
$ bundle exec rspec
```

> Note: You'll need to update the `buildpack_spec.rb` file to remove the exception

You can also focus a specific file or test by providing a path and line number:

```
$ bundle exec rspec spec/hatchet/buildpack_spec:5
```

Keep reading to find out more about how hatchet works.

## Concepts

### Specify buildpack

Tell Hatchet what buildpack you want to use by default by setting environment variables, this is commonly done in the `spec_helper.rb` file:

```ruby
ENV["HATCHET_BUILDPACK_BASE"] = "https://github.com/path-to-your/buildpack"
require 'hatchet'`
```

If you do not specify `HATCHET_BUILDPACK_BASE` the default Ruby buildpack will be used. If you do not specify a `HATCHET_BUILDPACK_BRANCH` the current branch you are on will be used. This is how the Ruby buildpack runs tests on branches on CI (by leaving `HATCHET_BUILDPACK_BRANCH` blank).

The workflow generally looks like this:

1. Make a change to the codebase
2. Commit it and push to GitHub so it's publicly available
3. Execute your test suite or individual test
4. Repeat until you're happy
5. Be happy

### Example apps:

Hatchet works by deploying example apps to Heroku's production service first you'll need an app to deploy that works with the buildpack you want to test. This method is preferred if you've got a very small app that might only need one or two files. There are two ways to give Hatchet a test app, you can either specify a remote app or a local directory.

- **Local directory use of Hatchet:**

```ruby
Hatchet::Runner.new("path/to/local/directory").deploy do |app|
end
```

An example of this is the [heroku/nodejs buildpack tests](https://github.com/heroku/heroku-buildpack-nodejs/blob/9898b875f45639d9fe0fd6959f42aea5214504db/spec/ci/node_10_spec.rb#L6).

You can either check in your apps to your source control or, you can use code to generate them, for example:

- [Generating an example app](https://github.com/sharpstone/force_absolute_paths_buildpack/blob/53c3cffb039fd366b5abb4524fb32983c11f9344/spec/hatchet/buildpack_spec.rb#L5-L20)
- [Source code for `generate_fixture_app`](https://github.com/sharpstone/force_absolute_paths_buildpack/blob/53c3cffb039fd366b5abb4524fb32983c11f9344/spec/spec_helper.rb#L34-L64)

If you generate example apps programmatically, then add the folder you put them in to your `.gitignore`.

> Note: If you're not using the `hatchet.json` you'll still need an empty one in your project with contents `{}`

- **Github app use of Hatchet:**

Instead of storing your apps locally or generating them, you can point Hatchet at a remote github repo. This method of storing apps on GitHub is preferred is you have an app that is large or has many files (for example, a Rails app).

Hatchet expects a json file in the root of your buildpack called `hatchet.json`. You can configure the install options using the `"hatchet"` key. In this example, we're telling Hatchet to install the given repos to our `test/fixtures` directory instead of the current default directory.

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

If you have conflicting names, use full paths like `Hatchet::Runner.new("sharpstone/no_lockfile")`.

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
- - test/fixtures/repos/lock/lock_fail_main
  - main
- - test/fixtures/repos/rails2/rails2blog
  - b37357a498ae5e8429f5601c5ab9524021dc2aaa
- - test/fixtures/repos/rails3/rails3_mri_193
  - 88c5d0d067cfd11e4452633994a85b04627ae8c7
```

> Note: If you don't want to lock to a specific commit, you can always use the latest commit by specifying `main` manually as seen above. This will always give you the latest commit on the `main` branch. The `master` keyword is supported as well.

### Deploying apps

Once you've got an app and have set up your buildpack, you can deploy an app and assert based on the output (all examples use rspec for testing framework).

```ruby
Hatchet::Runner.new("default_ruby").deploy do |app|
  expect(app.output).to match("Installing dependencies using bundler")
end
```

By default, an error will be raised if the deploy doesn't work, which forces the test to fail. If you're trying to test failing behavior (for example you want to test that an app without a `Gemfile.lock` fails to build), you can manually allow failures:

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

In this example, Hatchet is calling `heroku run which node` and passing the results back to the test so we can assert against it.

- **Asserting exit status:**

In ruby the way you assert a command you ran on the shell was successful or not is by using the `$?` "magic object". By default calling `app.run` will set this variable which can be used in your tests:

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

Hatchet is designed to play nicely with running tests in parallel via threads or processes. To support this the code that is executed in the `deploy` block is being run in a new directory. This allows you to modify files on disk safely without having to worry about race conditions. Still, it introduces the unexpected behavior that changes might not work like you think they will.

One typical pattern is to have a minimal example app, and then to modify it as needed before your tests. You can do this safely using the `before_deploy` block.

```ruby
Hatchet::Runner.new("default_ruby").tap do |app|
  app.before_deploy do
    out = `echo 'ruby "2.7.1"' >> Gemfile`
    raise "Echo command failed: #{out}" unless $?.success?
  end
  app.deploy do |app|
    expect(app.output).to include("Using Ruby version: ruby-2.6.6")
  end
end
```

This example will add the string `ruby "2.7.1"` to the end of the Gemfile on disk. It accomplishes this by shelling out to `echo`. If you prefer, you can directly use `File.open` to write contents to disk.

> Note: The above [tap method in ruby](https://ruby-doc.org/core-2.4.0/Object.html#method-i-tap) returns itself in a block, it makes this example cleaner.

> Note: that we're checking the status code of the shell command we're running (shell commands are executed via backticks in ruby), a common pattern is to write a simple helper function to automate this:

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

> Note: that `%Q{}` is a method of creating a string in Ruby if we didn't use it here we could escape the quotes:

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

And later:

```
Destroying "hatchet-t-fd25e3626b". Hatchet app limit: 80
```

By default, Hatchet does not destroy your app at the end of the test run, that way if your test failed unexpectedly if it's not destroyed yet, you can:

```
$ heroku run bash -a hatchet-t-bed73940a6
```

And use that to debug. Hatchet deletes old apps on demand. You tell it what your limits are and it will stay within those limits:

```
HATCHET_APP_LIMIT=20
```

With these env vars, Hatchet will "reap" older hatchet apps when it sees there are 20 or more hatchet apps. For CI, it's recommended that you increase the `HATCHET_APP_LIMIT` to 80-100. Hatchet will mark apps as safe for deletion once they've finished, and the `teardown!` method has been called on them (it tracks this by enabling maintenance mode on apps). Hatchet only tracks its apps. Hatchet uses a regex pattern on the name of apps to see which ones it can manage. If your account has reached the maximum number of global Heroku apps, you'll need to remove some manually.

If an app is not marked as being in maintenance mode for some reason, it can be deleted, but only after it has been allowed to live for some time. This behavior is configured by the `HATCHET_ALIVE_TTL_MINUTES` env var. For example, if you set it for `7`, Hatchet will ensure that any apps that are not marked as being in maintenance mode are allowed to live for at least seven minutes. This should give the app time to finish the test's execution, so it is not deleted mid-deploy. When this deletion happens, you'll see a warning in your output. It could indicate you're not properly cleaning up and calling `teardown!` on some of your apps, or it could mean that you're attempting to execute more tests concurrently than your `HATCHET_APP_LIMIT` allows. This deletion-mid-test behavior might otherwise be triggered if you have multiple CI runs executing at the same time.

It's recommended you don't use your personal Heroku API key for running tests on a CI server since the hatchet apps count against your account maximum limits. Running tests using your account locally is fine for debugging one or two tests.

If you find your local account has hit your maximum app limit, one handy trick is to get rid of any old "default" Heroku apps you've created. This plugin (https://github.com/hunterloftis/heroku-destroy-temp) can help:

```
$ heroku plugins:install heroku-destroy-temp
$ heroku apps:destroy-temp
```

> This won't detect hatchet apps, but it's still handy for cleaning up other unused apps.

### Deploying multiple times

If your buildpack uses the cache, you'll likely want to deploy multiple times against the same app to assert the cache was used. Here's an example of how to do that:

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

> Note: That  thing returned by the `run_ci` command is not an "app" object but rather a `test_run` object.

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

Do **NOT** specify a `buildpacks` key in the `app.json` because Hatchet will automatically do this for you. If you need to set buildpacks, you can pass them into the `buildpacks:` keyword argument:

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

Sometimes you might want to assert something against a test app without deploying. This modification is tricky if you're modifying files or the environment in your test. To help out there's a helper `in_directory_fork`:

```ruby
Hatchet::App.new('rails6-basic').in_directory_fork do
  require 'language_pack/rails5'
  require 'language_pack/rails6'

  expect(LanguagePack::Rails5.use?).to eq(false)
  expect(LanguagePack::Rails6.use?).to eq(true)
end
```

## Running your buildpack tests on a CI service

Once you've got your tests working locally, you'll likely want to get them running on CI. For reference, see the [Circle CI config from this repo](https://github.com/heroku/hatchet/blob/master/.circleci/config.yml) and the [Heroku CI config from the ruby buildpack](https://github.com/heroku/heroku-buildpack-ruby/blob/master/app.json).

To make running on CI easier, there is a setup script in Hatchet that can be run on your CI server each time before your tests are executed:

```yml
bundle exec hatchet ci:setup
```

If you're a Heroku employee, see [private instructions for setting up test users](https://github.com/heroku/languages-team/blob/master/guides/create_test_users_for_ci.md) to generate a user a grab the API token.

Once you have an API token you'll want to set up these env vars with your CI provider:

```
HATCHET_APP_LIMIT=100
HATCHET_RETRIES=2
HEROKU_API_KEY=<redacted>
HEROKU_API_USER=<redacted@example.com>
```

You can reference this PR for getting a buildpack set up from scratch with tests to see what kinds of files you might need: https://github.com/sharpstone/force_absolute_paths_buildpack/pull/2.

## Reference docs

The `Hatchet::Runner.new` takes several arguments.

### Init options

- stack (String): The stack you want to deploy to on Heroku.

```ruby
Hatchet::Runner.new("default_ruby", stack: "heroku-16").deploy do |app|
  # ...
end
```

- name (String): The name of an app you want to use. If you choose to provide your own app name, then Hatchet will not reap it, you'll have to delete it manually.
- allow_failure (Boolean): If set to a truthy value then the test won't error if the deploy fails
- labs (Array): Heroku has "labs" that are essentially features that are not enabled by default, one of the most popular ones is "preboot" https://devcenter.heroku.com/articles/preboot.
- buildpacks (Array):  Pass in the buildpacks you want to use against your app

```ruby
Hatchet::Runner.new("default_ruby", buildpacks: ["heroku/nodejs", :default]).deploy do |app|
  # ...
end
```

In this example, the app would use the nodejs buildpack, and then `:default` gets replaced by your Git url and branch name.

- before_deploy (Block): Instead of using the `tap` syntax you can provide a block directly to hatchet app initialization. Example:

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

- `run_multi` (Boolean): Allows you to run more than a single "one-off" dyno at a time (the `HATCHET_EXPENSIVE_MODE` env var must be set to use this feature). By default, "free" Heroku apps are restricted to only allowing one dyno to run at a time. You can increase this limit by scaling an application to paid application, but it will incur charges against your application:

```ruby
Hatchet::Runner.new("default_ruby", run_multi: true).deploy do |app|
  # This code runs in the background
  app.run_multi("ls") do |out, status|
    expect(status.success?).to be_truthy
    expect(out).to include("Gemfile")
  end

  # This code runs in the background in parallel
  app.run_multi("ruby -v") do |out, status|
    expect(status.success?).to be_truthy
    expect(out).to include("ruby")
  end

  # This line will be reached before either of the above blocks finish
end
```

In this example, the `heroku run ls` and `heroku run ruby -v` will be executed concurrently. The order that the `run_multi` blocks execute is not guaranteed. You can toggle this `run_multi` setting on globally by using `HATCHET_RUN_MULTI=1`. Without this setting enabled, you might need to add a `sleep` between multiple `app.run` invocations.

WARNING: Enabling `run_multi` setting on an app will charge your Heroku account 🤑.
WARNING: Do not use `run_multi` if you're not using the `deploy` block syntax or manually call `teardown!` inside the text context [more info about how behavior does not work with the `after` block syntax in rspec](https://github.com/heroku/hatchet/issues/110).
WARNING: To work, `run_multi` requires your application to have a `web` process associated with it.

- `retries` (Integer): When passed in, this value will be used insead of the global `HATCHET_RETRIES` set via environment variable. When `allow_failures: true` is set as well as a retries value, then the application will not retry pushing to Heroku.

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
- `app.add_database()`: adds a database to the app, defaults to the "dev" database
- `app.update_stack()`: Change the app's stack to that specified (for example `"heroku-20"`). Will take effect on the next build.
- `app.run()`: Runs a `heroku run bash` session with the arguments, covered above.
- `app.run_multi()`: Runs a `heroku run bash` session in the background and yields the results. This requires the `run_multi` flag of the app to be set to `true`, which will charge your application (the `HATCHET_EXPENSIVE_MODE` env var must also be set to use this feature). Example above.
- `app.create_app`: Can be used to manually create the app without deploying it (You probably want `setup!` though)
- `app.setup!`: Gets the application in a state ready for deploy.
  - Creates the Heroku app
  - Sets up any specified labs (from initialization)
  - Sets up any specified buildpacks
  - Sets up specified config
  - Calls the contents of the `before_deploy` block
- `app.before_deploy`: Allows you to update the `before_deploy` block

```ruby
Hatchet::Runner.new("default_ruby").tap do |app|
  app.before_deploy do
    FileUtils.touch("foo.txt")
  end
  app.deploy do
  end
end
```

Has the same result as:

```ruby
before_deploy_proc = Proc.new do
  FileUtils.touch("foo.txt")
end

Hatchet::Runner.new("default_ruby", before_deploy: before_deploy_proc).deploy do |app|
end
```

You can call multiple blocks by specifying (`:prepend` or `:append`):

```ruby
Hatchet::Runner.new("default_ruby").tap do |app|
  app.before_deploy do
    FileUtils.touch("foo.txt")
  end

  app.before_deploy(:append) do
    FileUtils.touch("bar.txt")
  end
  app.deploy do
  end
end
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

- `app.in_directory`: Runs the given block in a temp directory (but in the same process). One advanced debugging technique is to indefinitely pause test execution after outputting the directory so you can `cd` there and manually debug:

```ruby
Hatchet::Runner.new("python_default").in_directory do |app|
  puts "Temp dir is: #{Dir.pwd}"
  STDIN.gets("foo") # <==== Pauses tests until stdin receives "foo"
end
```

> Note: If you want to execute tests in this temp directory, you likely want to use `in_directory_fork` otherwise, you might accidentally contaminate the current environment's variables if you modify them.

- `app.in_directory_fork`: Runs the given block in a temp directory and inside of a forked process, an example given above.
- `app.original_source_code_directory`: Returns the directory of the example application on disk, this is NOT the temp directory that you're currently executing against. It's probably not what you want.
- `app.deploy`: Your main method takes a block to execute after the deploy is successful. If no block is provided, you must manually call `app.teardown!` (see below for an example).
- `app.output`: The output contents of the deploy
- `app.platform_api`: Returns an instance of the [platform-api Heroku client](https://github.com/heroku/platform-api). If Hatchet doesn't give you access to a part of Heroku that you need, you can likely do it with the platform-api client.
- `app.push!`: Push code to your Heroku app. It can be used inside of a `deploy` block to re-deploy.
- `app.run_ci`: Runs Heroku CI against the app returns a TestRun object in the block
- `app.teardown!`: This method is called automatically when using `app.deploy` in block mode after the deploy block finishes. When called it will clean up resources, mark the app as being finished (by setting `{"maintenance" => true}` on the app) so that the reaper knows it is safe to delete later. Here is an example of a test that creates and deploys an app manually, then later tears it down manually. If you deploy an application without calling `teardown!` then Hatchet will not know it is safe to delete and may keep it around for much longer than required for the test to finish.

```ruby
before(:each) do
  @app = Hatchet::Runner.new("default_ruby")
  @app.deploy
end

after(:each) do
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
HATCHET_BUILDPACK_BRANCH=<branch name if you dont want Hatchet to set it for you>
HATCHET_RETRIES=2
HATCHET_APP_LIMIT=(set to something low like 20 locally, set higher like 80-100 on CI)
HEROKU_API_KEY=<redacted>
HEROKU_API_USER=<redacted@redacted.com>
HATCHET_ALIVE_TTL_MINUTES=7

# HATCHET_RUN_MULTI=1      # WARNING: Setting this env var will incur charges against your account. To use this env var you must also enable `HATCHET_EXPENSIVE_MODE`
# HATCHET_EXPENSIVE_MODE=1 # WARNING: Do not set this environment variable unless you're okay with possibly large bills
```

> The syntax to set an env var in Ruby is `ENV["HATCHET_RETRIES"] = "2"` all env vars are strings.

- `HATCHET_BUILDPACK_BASE`: This is the URL where Hatchet can find your buildpack. It must be public for Heroku to be able to use your buildpack.
- `HATCHET_BUILDPACK_BRANCH`: By default, Hatchet will use your current git branch name. If, for some reason, git is not available or you want to manually specify it like `ENV["HATCHET_BUILDPACK_BRANCH'] = ENV[`MY_CI_BRANCH`]` then you can.
- `HATCHET_RETRIES` If the `ENV['HATCHET_RETRIES']` is set to a number, deploys are expected to work and automatically retry that number of times. Due to testing using a network and random failures, setting this value to `3` retries seems to work well. If an app cannot be deployed within its allotted number of retries, an error will be raised. The downside of a larger number is that your suite will keep running for much longer when there are legitimate failures.
- `HATCHET_APP_LIMIT`: The maximum number of **hatchet** apps that Hatchet will allow in the given account before running the reaper. For local execution, keep this low as you don't want your account dominated by hatchet apps. For CI, you want it to be much larger, 80-100 since it's not competing with non-hatchet apps. Your test runner account needs to be a dedicated account.
- `HEROKU_API_KEY`: The API key of your test account user. If you run locally without this set, it will use your personal credentials.
- `HEROKU_API_USER`: The email address of your user account. If you run locally without this set, it will use your personal credentials.
- `HATCHET_RUN_MULTI`: If enabled, this will scale up deployed apps to "standard-1x" once deployed instead of running on the free tier. This enables the `run_multi` method capability, however scaling up is not free. WARNING: Setting this env var will incur charges to your Heroku account. We recommended never to enable this setting unless you work for Heroku. To use this you must also set `HATCHET_EXPENSIVE_MODE=1`
- `HATCHET_EXPENSIVE_MODE`: This is intended to be a "safety" environment variable. If it is not set, Hatchet will prevent you from using the `run_multi: true` setting or the `HATCHET_RUN_MULTI` environment variables. There are still ways to incur charges without this feature, but unless you're absolutely confident your test setup will not leave "orphan" apps that are billing you, do not enable this setting. Even then, only set this value if you work for Heroku. To recap WARNING: setting this is expensive.

## Basic

### Basic rspec

Hatchet needs to run inside of a test framework such as minitest or rspec. Here's an example of some existing test suites that use Hatchet: [This project](https://github.com/heroku/hatchet) uses rspec to run it's own tests you can use these as a reference as well as the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby). If you're new to Ruby, testing, or Hatchet, it is recommended to reference other project's tests heavily. If you can't pick between minitest and rspec, go with rspec since that's what most reference tests use.

Whatever testing framework you chose, we recommend using a parallel test runner when running the full suite. [parallel_split_test](https://github.com/grosser/parallel_split_test).

**rspec plugins**  - Rspec has useful plugins, such as `gem 'rspec-retry'` which will re-run any failed tests a given number of times (I recommend setting this to at least 2) to decrease false negatives in your tests when running on CI.

Rspec is a testing framework for Ruby. It allows you to "describe" your tests using strings and blocks. This section is intended to be a brief introduction and includes a few pitfalls but is not comprehensive.

In your directory rspec assumes a `spec/` folder. It's common to have a `spec_helper.rb` in the root of that folder:

- **spec/spec_helper.rb**

Here's an example of a `spec_helper.rb`: https://github.com/sharpstone/force_absolute_paths_buildpack/blob/master/spec/spec_helper.rb

In this file, you'll require files you need to set up the project. You can also set environment variables like `ENV["HATCHET_BUILDPACK_BASE"]`. You can use it to configure your app. Any methods you define in this file will be available to your tests. For example:

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

This might look like a weird syntax, but it's valid ruby. It's shorthand for this:

```ruby
expect(value).to(eq(true))
```

Where `eq` is a method.

If you want to assert the opposite, you can use `to_not`:

```ruby
expect(value).to_not eq(false)
```

- **matcher syntax**

In the above example, the `eq` is called a "matcher". You're matching it against an object. In this case, you're looking for equality `==`.

There are other matchers: https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers

```ruby
expect(value).to be_truthy

value = "hello there"
expect(value).to include("there")
```

Rspec uses some "magic" to convert anything you pass to

Since most values in Hatchet are strings, the ones I use the most are:

- Rspec matchers
  - include https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers/include-matcher#string-usage
  - match https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers/match-matcher

Generally, I use the include when I know the exact value I want to assert against, I use match when there are dynamic values, and I want to be able to use a regular expression.

For building regular expressions, I like to use the tool https://rubular.com/ for developing and testing regular expressions. Ruby's regular expression engine is mighty.


- **Keep it simple**

Rspec is a massive library with a host of features. It's possible to quickly make your tests unmaintainable and unreadable in the efforts to keep your code [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). I recommend sticking to only the features mentioned here at first before trying to do anything fancy.

- **What to test**

Here's a PR with a description of several standard failure modes that lots of buildpacks should be aware of and reference implementations:

https://github.com/heroku/heroku-buildpack-python/pull/969

- **before(:all) gotcha**

In rspec you can use `before` blocks to execute before a test, and `after` blocks to execute after a test. This might sound like you can deploy a hatchet app once and then write multiple tests against that app. However if `before(:all)` can be executed N times if you're running via parallel processes. Example:

```ruby
# Warning running `before(:all)` in a multi-process test runner context likely executes your
# block N times where N is the number of tests in that context: https://github.com/grosser/parallel_split_test/pull/22/files
before(:all) do
  @app = Hatchet::Runner.new("default_ruby") # Warning: This is a gotcha
  @app.deploy
end

after(:all) do
  @app.teardown! if @app # Warning: This is a gotcha
end

it "tests app somehow" do
  expect(@app.run("ruby -v")).to match("ruby") # Warning: This is a gotcha
end


it "tests app somehow 2" do
  expect(@app.run("ls")).to match("Gemfile") # Warning: This is a gotcha
end
```

Running this via the parallel_split_test gem will cause the `before(:all)` block to be invoked multiple times:

```
$ PARALLEL_SPLIT_TEST_PROCESSES=3 bundle exec parallel_split_test spec/
Hatchet setup: "hatchet-t-af7dffc006"
Hatchet setup: "hatchet-t-bf7dffc006"
```

It would result in 2 apps being deployed. You can find more information [on the documentation](https://github.com/grosser/parallel_split_test#beforeall-rspec-hooks). For clarity of what will happen behind the scenes when running with multiple processes, it's recommended to use `before(:each)` instead of `before(:all)`.

### Basic Ruby

If you're not a Ruby specialist, not to worry. Here are a few things you might want to do:

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

You can define a multi-line string in Ruby using `<<~EOM` with a closing `EOM`. Technically, `EOM` can be any string, but you're not here for technicalities.

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

A hash is like a dict in python. Docs: https://ruby-doc.org/core-2.7.1/Hash.html

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

All values in an env var must be a string. See the Hash docs for more information on manipulating hashes https://ruby-doc.org/core-2.7.1/Hash.html. Also see the current ENV docs https://ruby-doc.org/core-2.7.1/ENV.html.

- **Strings versus symbols**

In Ruby you can have a define a symbol `:thing` as well as a `"string"`. They look and behave very closely but are different. A symbol is a singleton object, while the string is unique object. One really confusing thing is you can have a hash with both string and symbol keys:

```ruby
my_hash = {}
my_hash["dog"] = "cinco"
my_hash[:dog] = "river"
puts my_hash.inspect
# => {"dog"=>"cinco", :dog=>"river"}
```

- **Blocks, procs, and lambdas**

Blocks are a concept in Ruby for closure. Depending on how it's used it can be an anonymous method. It's always a method for passing around code. When you see `do |app|` that's the beginning of an implicit block. In addition to an implicit block you can create an explicit block using lambdas and procs. In Hatchet, these are most likely to be used to update the app `before_deploy`. Here's an example of some syntax for creating various blocks.

```ruby
before_deploy = -> { FileUtils.touch("foo.txt") } # This syntax is called a "stabby lambda"
before_deploy = lambda { FileUtils.touch("foo.txt") } # This is a more verbose lambda
before_deploy = lambda do
  FileUtils.touch("foo.txt") # Multi-line lambda
end
before_deploy = Proc.new { FileUtils.touch("foo.txt") } # A proc and lambda are subtly different, it mostly won't matter to you though
before_deploy = Proc.new do
  FileUtils.touch("foo.txt") # Multi-line proc
end
```

All of these things do the same thing more-or-less. You can execute a block/proc/lambda by running:

```ruby
before_deploy.call
```

- **Parens**

You might have noticed that some ruby methods use parens and some don't. I.e. `puts "yo"` versus `puts("yo")`. If the parser can determine your intent then you don't have to use parens.

- **Debugging**

If you're not used to debugging Ruby you can reference the [Ruby debugging magic cheat sheet](https://www.schneems.com/2016/01/25/ruby-debugging-magic-cheat-sheet.html). The Ruby language is very powerful in it's ability to [reflect on itself](https://en.wikipedia.org/wiki/Reflection_%28computer_programming%29). Essentially the Ruby code is able to introspect itself to tell you what it's doing. If you're ever lost, ask your ruby code. It might confuse you, but it won't lie to you.

Another good debugging tool is the [Pry debugger and repl](https://github.com/pry/pry).

- **Common Ruby errors**

```
SyntaxError ((irb):14: syntax error, unexpected `end')
```

If you see this, it likely means you forgot a `do` on a block, for example `.deploy |app|` instead of `.deploy do |app|`.

```
NoMethodError (undefined method `upcase' for nil:NilClass)
```

If you see this it means a variable you're using is `nil` unexpectedly. You'll need to use the [above debugging techniques](https://www.schneems.com/2016/01/25/ruby-debugging-magic-cheat-sheet.html) to figure out why.

- **More**

Ruby is full of multitudes, this isn't even close to being exhaustive, just enough to make you dangerous and write a few tests. It's infinitely useful for testing, writing CLIs and web apps.

## Hatchet CLI

Hatchet has a CLI for installing and maintaining external repos you're
using to test against. If you have Hatchet installed as a gem run

    $ Hatchet --help

For more info on commands. If you're using the source code you can run
the command by going to the source code directory and running:

    $ ./bin/hatchet --help


## Developing Hatchet

If you want to add a feature to Hatchet (this library) you'll need to install it locally and be able to run the tests:


## Install locally

```
$ git clone https://github.com/heroku/hatchet
$ cd hatchet
$ bundle install
```

### Run the Tests

```
$ PARALLEL_SPLIT_TEST_PROCESSES=10 bundle exec parallel_split_test spec/
```
This will execute all tests, you can also run a single test by specifying a file and line number:

```
$ bundle exec rspec spec/hatchet/app_spec.rb:4
```

## License

MIT
