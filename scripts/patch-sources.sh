#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
patch_file="$PWD/patches/pappl-no-status-ui.patch"
cd vendor/pappl-1.4.10
if patch --force --dry-run -R -p1 < "$patch_file" >/dev/null 2>&1; then
  exit 0
fi
patch --batch -p1 < "$patch_file"
