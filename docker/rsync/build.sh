#!/bin/sh
#
# Download, compile and install the given rsync versions side by side
#
# Usage: build.sh VERSION...
#
# Each version is installed as /usr/lib/rsync/<version>/rsync
#

set -eu

for version in "$@"; do
  echo "Building rsync ${version}"

  src="/tmp/rsync-${version}"
  mkdir -p "${src}"

  wget -qO- "https://github.com/RsyncProject/rsync/archive/refs/tags/v${version}.tar.gz" \
    | tar -xz -C "${src}" --strip-components=1

  cd "${src}"

  ./configure --disable-md2man
  make -j"$(nproc)" rsync

  install -D -m 755 -s rsync "/usr/lib/rsync/${version}/rsync"

  # Verify the installed binary reports the expected version
  "/usr/lib/rsync/${version}/rsync" --version | head -n 1 | grep -F "version ${version} "

  cd /
  rm -rf "${src}"
done
