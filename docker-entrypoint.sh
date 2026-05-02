#!/bin/sh
set -e

bundle exec rails db:prepare
bundle exec rails database:seed:production

exec "$@"
