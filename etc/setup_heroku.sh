#!/usr/bin/env bash

set -euo pipefail
curl --fail --retry 3 --retry-delay 1 --connect-timeout 3 --max-time 30 https://cli-assets.heroku.com/install.sh | sh
