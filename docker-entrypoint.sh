#!/bin/sh
set -e

case " $* " in
  *"rails server "*)
    # Only the web server prepares and seeds the database, to avoid concurrent migrations
    bundle exec rails db:prepare
    bundle exec rails database:seed:production

    if [ "${RAILS_ENV}" = "development" ]; then
      bundle exec rails database:seed:development
    fi
    ;;
  *)
    # Other processes (e.g. the background worker) wait until the database is ready
    until bundle exec rails db:abort_if_pending_migrations > /dev/null; do
      echo "Waiting for database migrations..."
      sleep 5
    done
    ;;
esac

exec "$@"
