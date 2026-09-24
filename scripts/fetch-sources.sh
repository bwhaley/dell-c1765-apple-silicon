#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p vendor
while read -r archive url; do
  expected=$(awk -v path="vendor/$archive" '$2 == path {print $1}' scripts/sources.sha256)
  test -n "$expected"
  if [ -f "vendor/$archive" ]; then
    actual=$(shasum -a 256 "vendor/$archive" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then continue; fi
    echo "Checksum mismatch: vendor/$archive. Remove it to download a fresh copy." >&2
    exit 1
  fi
  temporary=$(mktemp "vendor/$archive.XXXXXX")
  trap 'rm -f "$temporary"' EXIT HUP INT TERM
  curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' "$url" -o "$temporary"
  actual=$(shasum -a 256 "$temporary" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then echo "Checksum mismatch: $archive" >&2; exit 1; fi
  mv "$temporary" "vendor/$archive"
  trap - EXIT HUP INT TERM
done < scripts/sources.urls
shasum -a 256 -c scripts/sources.sha256
