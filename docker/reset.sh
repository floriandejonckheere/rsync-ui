#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../tmp/data"

RESTART=0
YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --restart) RESTART=1; shift ;;
    -y|--yes)  YES=1; shift ;;
    *) shift ;;
  esac
done

echo "This will clear all rsync destination repositories:"
echo "  - Photos          ($DATA_DIR/app/photos)"
echo "  - Docker Replica  ($DATA_DIR/app/docker-replica)"
echo "  - Home Backup     ($DATA_DIR/backup/home)"
echo "  - Projects Backup ($DATA_DIR/backup/projects)"
echo "  - Photos Mirror   ($DATA_DIR/mirror/photos)"
echo ""

if [ "$YES" -eq 0 ]; then
  printf "Continue? [y/N] "
  read -r answer
  case "$answer" in
    [yY]*) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

clear_dir() {
  label="$1"
  dir="$2"
  printf "Clearing %-20s" "$label..."
  if [ -d "$dir" ]; then
    find "$dir" -mindepth 1 -delete
    echo " done"
  else
    echo " (skipped, directory does not exist)"
  fi
}

clear_dir "Photos"          "$DATA_DIR/app/photos"
clear_dir "Docker Replica"  "$DATA_DIR/app/docker-replica"
clear_dir "Home Backup"     "$DATA_DIR/backup/home"
clear_dir "Projects Backup" "$DATA_DIR/backup/projects"
clear_dir "Photos Mirror"   "$DATA_DIR/mirror/photos"

echo ""
echo "All destination repositories cleared."

if [ "$RESTART" -eq 1 ]; then
  echo ""
  echo "Restarting Docker containers..."
  docker compose -f "$SCRIPT_DIR/../compose.yml" restart backup mirror worker app
  echo "Done."
fi
