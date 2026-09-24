#!/bin/sh
# Print one validated Bonjour hostname per supported remote printer.
set -eu
# Only physical C1765nfw raw-print services on the port used by our encoder.
# Do not match the native bridge or arbitrary devices containing "Dell".
results=$(ippfind -T 8 _pdl-datastream._tcp --remote --port 9100 \
  --txt-ty '^Dell[[:space:]]+C1765nfw([[:space:]]+Color[[:space:]]+MFP)?$' \
  --exec /usr/bin/printf '%s\n' '{service_hostname}' ';') || {
  status=$?
  # ippfind returns 1 when nothing matches; other statuses indicate an error.
  if [ "$status" -ne 1 ]; then
    echo 'Bonjour discovery could not complete. Check network access and try again.' >&2
  fi
  exit "$status"
}
printf '%s\n' "$results" | LC_ALL=C awk '
  /^[A-Za-z0-9][A-Za-z0-9.-]*$/ {
    host=tolower($0); sub(/\.$/, "", host)
    if (host != "localhost" && host != "localhost.local" && host !~ /^127\./)
      print host
  }' | LC_ALL=C sort -u
