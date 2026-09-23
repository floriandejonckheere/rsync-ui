#!/bin/sh
set -e

bundle exec rails db:prepare
bundle exec rails database:seed:production

if [ "${RAILS_ENV}" = "development" ]; then
  bundle exec rails database:seed:development
fi

exec "$@"
