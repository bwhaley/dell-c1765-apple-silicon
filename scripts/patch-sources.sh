#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
root="$PWD"
cd vendor/pappl-1.4.10
for patch_file in "$root"/patches/pappl-*.patch; do
  if patch --force --dry-run -R -p1 < "$patch_file" >/dev/null 2>&1; then
    continue
  fi
  patch --batch -p1 < "$patch_file"
done
