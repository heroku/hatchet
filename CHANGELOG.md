## HEAD

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