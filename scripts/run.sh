#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/state build/spool
export XDG_CONFIG_HOME="$PWD/build/state"
exec build/bin/dell-printer server -o server-port=8631 -o listen-hostname=localhost \
  -o server-hostname=localhost -o "spool-directory=\"$PWD/build/spool\"" \
  -o "log-file=\"$PWD/build/service.log\"" -o log-level=debug
