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


## Writing Tests

Hatchet is meant for running integration tests, which means we actually have to deploy a real live honest to goodness app on Heroku and see how it behaves.

First you'll need a repo to an app you know works on Heroku, add it to the proper folder in repos. Such as `repos/rails3/`. Once you've done that make a corresponding test file in the `test` dir such as `test/repos/rails3`. I've already got a project called "codetriage" and the test is "triage_test.rb".

Now that you have an app, we'll need to create a heroku instance, and deploy our code to that instance you can do that with this code:

    Hatchet::App.new("repos/rails3/codetriage").deploy do |app|
      ##
    end

The first argument to the app is the directory where you can find the code. Once your test is done, the app will automatically be destroyed.

Now that you've deployed your app you'll want to make sure that the deploy worked correctly. Since we're using `test/unit` you can use regular assertions such as `assert` and `refute`. Since we're yielding to an `app` variable we can check the `deployed?` status of the app:

    Hatchet::App.new("repos/rails3/codetriage").deploy do |app|
      assert app.deployed?
    end

The primary purpose of the buildpack is configuring and deploying apps, so if it deployed chances are the buildpack is working correctly, but sometimes you may want more information. You can run arbitrary commands such as `heroku bash` and then check for the existence of a file.

    Hatchet::App.new("repos/rails3/codetriage").deploy do |app|
      app.run("bash") do |cmd|
        assert cmd.run("ls public/assets").include?("application.css")
      end
    end

Anything you put in `cmd.run` at this point will be executed from with in the app that you are in.

    cmd.run("cat")
    cmd.run("cd")
    cmd.run("cd .. ; ls | grep foo")

It behaves exactly as if you were in a remote shell. If you really wanted you could even run the tests:

    cmd.run("rake test")

But since cmd.run doesn't return the exit status now, that wouldn't be
so useful (also there is a default timeout to all commands). If you want
you can configure the timeout by passing in a second parameter

    cmd.run("rake test", 180.seconds)


## Running One off Commands

If you only want to run one command you can call `app.run` without
passing a block

    Hatchet::AnvilApp.new("/codetriage").deploy do |app|
      assert_match "1.9.3", app.run("ruby -v")
    end


## Testing A Different Buildpack

You can specify buildpack to deploy with like so:

    Hatchet::App.new("repos/rails3/codetriage", buildpack: "https://github.com/schneems/heroku-buildpack-ruby.git").deploy do |app|

## Hatchet Config

Hatchet is designed to test buildpacks, and requires full repositories
to deploy to Heroku. Web application repos, especially Rails repos, aren't known for
being small, if you're testing a custom buildpack and have
`BUILDPACK_URL` set in your app config, it needs to be cloned each time
you deploy your app. If you've `git add`-ed a bunch of repos then this
clone would be pretty slow, we're not going to do this. Do not commit
your repos to git.

Instead we will keep a structured file called
inventively `hatchet.json` at the root of your project. This file will
describe the structure of your repos, have the name of the repo, and a
git url. We will use it to sync remote git repos with your local
project. It might look something like this

    {
      "hatchet": {},
      "rails3": ["git@github.com:codetriage/codetriage.git"],
      "rails2": ["git@github.com:heroku/rails2blog.git"]
    }

the 'hatchet' object accessor is reserved for hatchet settings.
. To copy each repo in your `hatchet.json`
run the command:

    $ hatchet install

The above `hatchet.json` will produce a directory structure like this:

    repos/
      rails3/
        codetriage/
          #...
      rails2/
        rails2blog/
          # ...

While you are running your tests if you reference a repo that isn't
synced locally Hatchet will raise an error. Since you're using a
standard file for your repos, you can now reference the name of the git
repo, provided you don't have conflicting names:

    Hatchet::App.new("codetriage").deploy do |app|

If you do have conflicting names, use full paths.

A word of warning on including rails/ruby repos inside of your test
directory, if you're using a runner that looks for patterns such as
`*_test.rb` to run your hatchet tests, it may incorrectly think you want
to run the tests inside of the rails repositories. To get rid of this
problem move your repos direcory out of `test/` or be more specific
with your tests such as moving them to a `test/hatchet` directory and
changing your pattern if you are using `Rake::TestTask` it might look like this:

    t.pattern = 'test/hatchet/**/*_test.rb'

A note on external repos: since you're basing tests on these repos, it
is in your best interest to not change them or your tests may
spontaneously fail. In the future we may create a hatchet.lockfile or
something to declare the commit

## Hatchet CLI

Hatchet has a CLI for installing and maintaining external repos you're
using to test against. If you have Hatchet installed as a gem run

    $ hatchet --help

For more info on commands. If you're using the source code you can run
the command by going to the source code directory and running:

    $ ./bin/hatchet --help


## Retries

Phantom errors happen. To auto retry deploy failures set the environment variable `HATCHET_RETRIES=3` which will auto retry deploys 3 times. By default deploys will not be retried. Once the number of retries has occurred the last exception will be raised.

## The Future

### Speed

Efforts may be spent optimizing / parallelizing the process, almost all of the time of the test is spent waiting for IO, so hopefully we should be able to parallelize many tests / deploys at the same time. The hardest part of this (i believe) would be splitting out the different runs into different log streams so that the output wouldn't be completely useless.

Right now running 1 deploy test takes about 3 min on my machine.

## Git Based Deploys

It would be great to allow hatchet to deploy apps off of git url, however if we do that we could open ourselves up to false negatives, if we are pointing at an external repo that gets broken.


## Features?

What else do we want to test? Config vars, addons, etc. Let's write some tests.
