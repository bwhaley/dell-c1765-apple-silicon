#!/bin/sh
# Write only the selected hostname to stdout; user-facing text goes to stderr.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
printer_host=${1:-}
if [ -z "$printer_host" ]; then
  echo 'Looking for Dell C1765nfw printers on your network…' >&2
  candidates=$(sh "$script_dir/discover-printers.sh") || candidates=
  count=$(printf '%s\n' "$candidates" | awk 'NF {n++} END {print n+0}')
  case "$count" in
    0)
      echo 'No Dell C1765nfw found. Check that it is on and on the same network, with Bonjour enabled.' >&2
      printf 'Enter its IP address or hostname, or press Return to cancel: ' >&2
      IFS= read -r printer_host || printer_host=
      ;;
    1)
      printer_host=$candidates
      echo "Found Dell C1765nfw at $printer_host." >&2
      ;;
    *)
      echo 'Multiple Dell C1765nfw printers found:' >&2
      printf '%s\n' "$candidates" | awk '{printf "  %d) %s\n", NR, $0}' >&2
      printf 'Choose a printer number, or press Return to cancel: ' >&2
      IFS= read -r choice || choice=
      case "$choice" in *[!0-9]*|'') echo 'Installation cancelled.' >&2; exit 1;; esac
      printer_host=$(printf '%s\n' "$candidates" | awk -v choice="$choice" 'NR == choice {print}')
      ;;
  esac
fi
case "$printer_host" in
  '') echo 'Installation cancelled.' >&2; exit 1;;
  *[!a-zA-Z0-9.-]*|[-.]*) echo 'Use a printer IP address or hostname.' >&2; exit 1;;
esac
printf '%s\n' "$printer_host"
