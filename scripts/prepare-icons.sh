#!/bin/sh
# Dell artwork is separately attributed in assets/README.md.
set -eu
destination=$1
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_icon=${2:-"$script_dir/../assets/DellC1765.icns"}
test -r "$source_icon"
mkdir -p "$destination"
cp "$source_icon" "$destination/DellC1765.icns"
sips -s format png "$source_icon" --out "$destination/icon-lg.png" >/dev/null
sips -z 128 128 "$destination/icon-lg.png" --out "$destination/icon-md.png" >/dev/null
sips -z 48 48 "$destination/icon-lg.png" --out "$destination/icon-sm.png" >/dev/null
