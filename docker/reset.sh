#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../tmp/data"

reset_dir() {
  label="$1"
  dir="$2"
  echo "Resetting $label repository..."
  if [ -d "$dir" ]; then
    find "$dir" -mindepth 1 -print -delete
  else
    echo "  (skipping, directory does not exist)"
  fi
}

reset_dir "Photos"          "$DATA_DIR/app/photos"
reset_dir "Docker Replica"  "$DATA_DIR/app/docker-replica"
reset_dir "Home Backup"     "$DATA_DIR/backup/home"
reset_dir "Projects Backup" "$DATA_DIR/backup/projects"
reset_dir "Photos Mirror"   "$DATA_DIR/mirror/photos"

echo "Done."
