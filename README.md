# Hatchet

![](http://f.cl.ly/items/2M2O2Q2I2x0e1M1P2936/Screen%20Shot%202013-01-06%20at%209.59.38%20PM.png)

Hatchet is a an integration testing library for developing Heroku buildpacks.

[![Build Status](https://travis-ci.org/heroku/hatchet.png?branch=master)](https://travis-ci.org/heroku/hatchet)

## Install

First run:

    $ bundle install

This library uses the heroku-api gem, you will need to make your API key
available to the system.

You can get your token by running:

    $ heroku auth:token
    alskdfju108f09uvngu172019


We need to export this token into our environment open up your `.bashrc`

    export HEROKU_API_KEY="alskdfju108f09uvngu172019"

Then source the file. If you don't want to set your api key system wide,
it will be pulled automatically via shelling out, but this is slower.

## Run the Tests

    $ bundle exec rake test

## Why Test a Buildpack?

To prevent regressions and to make pushing out new features faster and easier.

## What can Hatchet Test?

Hatchet can easily test deployment of buildpacks, getting the build output, and running arbitrary interactive processes such as `heroku run bash`.

## Testing a Buildpack

Hatchet was built for testing the Ruby buildpack, but you can use it to test any buildpack you desire provided you don't mind writing your tests written in Ruby.

You will need copies of applications that can be deployed by your buildpack. You can see the ones for the Hatchet unit tests (and the Ruby buildpack) https://github.com/sharpstone. Hatchet does not require that you keep these apps checked into your git repo which would make fetching your buildpack slow instead declare them in a `hatchet.json` file (see below).

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


## Deployments: Anvil vs. Git

Before you start testing a buildpack, understand that there are two different ways to deploy to Heroku. The first you are likely familiar with Git, requires a `git push heroku master`. You can configure the buildpack of an app being deployed in this way through the `BUILDPACK_URL` environment variable of the app. The buildpack url must be publicaly available.

The second method is by [Anvil](https://github.com/ddollar/anvil-cli) . In this method the build is performed as a service. This service takes an app to be built as well as a buildpack. When using Anvil, you do not need to put your buildpack anywhere publicly available.

When developing local features you will likely wish to use Anvil since it does not require a publicly available URL and you can iterate faster. When testing for regression you will almost always want to use Git, since it is the closest approximation to real world deployment. For this reason Hatchet provides a globally configurable way to toggle between the two deployment modes `Hatchet::Runner`


## Deploying apps

Now that you've got your apps locally you can have hatchet deploy them for you. Hatchet can deploy using one of two ways Anvil and Git. To specify one or the other set your `HATCHET_DEPLOY_STRATEGY` environment variable to `anvil` or `git`. The default is `anvil`. In production, you should always test against `git`


A `Hatchet::GitApp` will deploy using the standard `git push heroku master` and is not configurable, if you use this option you need to have a publicly accessible copy of your buildpack. Using Git to test your buildpack may be slow and require you to frequently push your buildpack to a public git repo. For this reason we recommend using Anvil to run your tests locally:

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|

end
```

If you are using GIT, you can specify the location of your public buildpack url in an environment variable:

```sh
HATCHET_BUILDPACK_BASE=https://github.com/heroku/heroku-buildpack-ruby.git
HATCHET_BUILDPACK_BRANCH=master
```

If you do not specify `HATCHET_BUILDPACK_URL` the default Ruby buildpack will be used. If you do not specify a `HATCHET_BUILDPACK_BRANCH` the current branch you are on will be used.

Deploys are expected to work, if the `ENV['HATCHET_RETRIES']` is set, then deploys will be automatically retried that number of times. Due to testing using a network and random Anvil failures, setting this value to `3` retries seems to work well. If an app cannot be deployed within its allotted number of retries an error will be raised.

If you are testing an app that is supposed to fail deployment you can set the `allow_failure: true` flag when creating the app:

```ruby
Hatchet::Runner.new("no_lockfile", allow_failure: true).deploy do |app|
```

After the block finishes your app will be removed from heroku. If you are investigating a deploy, you can add the `debug: true` flag to your app:

```ruby
Hatchet::Runner.new("rails3_mri_193", debug: true).deploy do |app|
```

Now after Hatchet is done deploying your app it will remain on Heroku. It will also output the name of the app into your test logs so that you can `heroku run bash` into it for detailed postmortem.

If you are wanting to run a test against a specific app without deploying to it, you can set the app name like this:

```ruby
app = Hatchet::Runner.new("rails3_mri_193", name: "testapp")
```

Deploying the app takes a few minutes, so you may want to skip that part to make debugging a problem easier since you're iterating much faster.


If you need to deploy using a buildpack that is not in the root of your directory you can specify a path in the `buildpack` option:


```ruby
buildpack_path = File.expand_path 'test/fixtures/buildpacks/heroku-buildpack-ruby'

def test_deploy
  Hatchet::GitApp.new("rails3_mri_193", buildpack: buildpack_path).deploy do |app|
  # ...
```

If you are using a `Hatchet::GitApp` this is where you specify the publicly avaialble location of your buildpack, such as `https://github.com/heroku/heroku-buildpack-ruby.git#mybranch`


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

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  app.run("bash") do |bash|
    bash.run("ls")           {|result| assert_match "Gemfile.lock", result }
    bash.run("cat Procfile") {|result| assert_match "web:", result }
  end
end
```

or

```ruby
Hatchet::Runner.new("rails3_mri_193").deploy do |app|
  app.run("rails console") do |console|
    console.run("a = 1 + 2")  {|result| assert_match "3", result }
    console.run("'foo' * a")  {|result| assert_match "foofoofoo", result }
  end
end
```

This functionality is provided by [repl_runner](http://github.com/schneems/repl_runner). Please read the docs on that readme for more info. The only interactive commands that are supported out of the box are `rails console`, `bash`, and `irb` it is fairly easy to add your own though:

```
ReplRunner.register_commands(:python)  do |config|
  config.terminate_command "exit()"        # the command you use to end the 'python' console
  config.startup_timeout 60                # seconds to boot
  config.return_char "\n"                  # the character that submits the command
end
```

If you have questions on setting running other interactive commands message [@schneems](http://twitter.com/schneems)

## Writing Tests

Hatchet is test framework agnostic. [This project](https://github.com/heroku/hatchet) uses `Test::Unit` to run it's own tests. While the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby) uses rspec.

Rspec has a number of advantages, the ability to run `focused: true` to only run the exact test you want as well as the ability to tag tests. Rspec also has a number of useful plugins, one especialy useful one is `gem 'rspec-retry'` which will re-run any failed tests a given number of times (I recommend setting this to at least 2) this decrease the number of false negatives your tests will have.

Whatever testing framework you chose, we recommend using a parallel test runner when running the full suite [parallel_tests](https://github.com/grosser/parallel_tests) works with rspec and test::unit and is amazing.

If you're unfamiliar with the ruby testing eco-system or want some help with boilerplate and work for Heroku: [@schneems](http://twitter.com/schneems) can help you get started. Looking at existing projects is a good place to get started

## Testing on Travis

Once you've got your tests working locally, you'll likely want to get them running on Travis because a) CI is awesome, and b) you can use pull requests to run your all your tests in parallel without having to kill your network connection.

You will want to set the `HATCHET_DEPLOY_STRATEGY` to `git`.

To run on travis you will need to configure your `.travis.yml` to run the appropriate commands and to set up encrypted data so you can run tests against a valid heroku user.

For reference see the `.travis.yml` from [hatchet](https://github.com/heroku/hatchet/blob/master/.travis.yml) and the [heroku-ruby-buildpack](https://github.com/heroku/heroku-buildpack-ruby/blob/master/.travis.yml). To make running on travis easier there is a rake task in Hatchet that can be run before your tests are executed

```
before_script: bundle exec rake hatchet:setup_travis
```

I recommend signing up for a new heroku account for running your tests on travis, otherwise you will quickly excede your API limit. Once you have the new api token you can use this technique to [securely send travis the data](http://about.travis-ci.org/docs/user/build-configuration/#Secure-environment-variables).


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


