# Hatchet

## What

The Hatchet is a an integration testing library for developing Heroku buildpacks.

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

But since cmd.run doesn't return the exit status now, that wouldn't be so useful (also there is a default timeout to all commands).


## Testing A Different Buildpack

You can specify buildpack to deploy with like so:

    Hatchet::App.new("repos/rails3/codetriage", buildpack: "https://github.com/schneems/heroku-buildpack-ruby.git").deploy do |app|



## The Future

### Speed

Efforts may be spent optimizing / parallelizing the process, almost all of the time of the test is spent waiting for IO, so hopefully we should be able to parallelize many tests / deploys at the same time. The hardest part of this (i believe) would be splitting out the different runs into different log streams so that the output wouldn't be completely useless.

Right now running 1 deploy test takes about 3 min on my machine.

## Git Based Deploys

It would be great to allow hatchet to deploy apps off of git url, however if we do that we could open ourselves up to false negatives, if we are pointing at an external repo that gets broken.


## Features?

What else do we want to test? Config vars, addons, etc. Let's write some tests.