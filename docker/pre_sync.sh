#!/bin/sh
set -e

JOB_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --job) JOB_NAME="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "[$(date -Iseconds)] Pre-sync hook started for job: ${JOB_NAME}"

echo "[$(date -Iseconds)] Pre-sync hook completed successfully"
