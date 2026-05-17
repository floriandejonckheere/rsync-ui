#!/bin/sh
set -e

echo "Creating Home repository data..."
mkdir -p \
  /data/home/Documents \
  /data/home/Downloads \
  /data/home/.config
dd if=/dev/zero of=/data/home/Documents/report-2026.pdf bs=1M count=3 status=none
dd if=/dev/zero of=/data/home/Documents/notes.txt bs=4K count=1 status=none
dd if=/dev/zero of=/data/home/Downloads/archive.zip bs=1M count=10 status=none
dd if=/dev/zero of=/data/home/.bashrc bs=4K count=1 status=none
dd if=/dev/zero of=/data/home/.vimrc bs=4K count=1 status=none

echo "Creating Projects repository data..."
mkdir -p \
  /data/projects/web-app/src \
  /data/projects/cli-tool/src \
  /data/projects/scripts
dd if=/dev/zero of=/data/projects/web-app/src/main.rb bs=8K count=1 status=none
dd if=/dev/zero of=/data/projects/web-app/Gemfile bs=4K count=1 status=none
dd if=/dev/zero of=/data/projects/cli-tool/src/cli.py bs=8K count=1 status=none
dd if=/dev/zero of=/data/projects/scripts/deploy.sh bs=4K count=1 status=none

echo "Creating Photos repository..."
mkdir -p /data/photos

echo "Creating Docker repository data..."
mkdir -p \
  /data/docker/volumes/db_data \
  /data/docker/volumes/app_data \
  /data/docker/volumes/cache
dd if=/dev/zero of=/data/docker/volumes/db_data/postgres.tar bs=1M count=50 status=none
dd if=/dev/zero of=/data/docker/volumes/app_data/storage.tar bs=1M count=20 status=none
dd if=/dev/zero of=/data/docker/volumes/cache/redis.rdb bs=1M count=5 status=none

echo "Creating Docker Replica repository..."
mkdir -p /data/docker-replica

bundle exec rails db:prepare
bundle exec rails database:seed:production

if [ "${RAILS_ENV}" = "development" ]; then
  bundle exec rails database:seed:development
fi

exec "$@"
