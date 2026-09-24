#!/bin/sh
set -eu
umask 077
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_dir="$HOME/Library/Application Support/DellNative"
agent="$HOME/Library/LaunchAgents/local.dell-native.printer.plist"
label=local.dell-native.printer
user_id=$(id -u)
printer_host=$(sh "$package_dir/select-printer.sh" "${1:-}")
if [ "$(uname -m)" != arm64 ]; then echo 'This build requires an Apple-silicon Mac.'; exit 1; fi
test -x "$package_dir/payload/bin/dell-printer"
test -x "$package_dir/payload/bin/foo2hbpl2"

# Stop only this installation's registered service before replacing its binaries.
if launchctl print "gui/$user_id/$label" >/dev/null 2>&1; then
  launchctl bootout "gui/$user_id/$label"
  attempt=0
  while /usr/bin/curl -fsS --max-time 2 http://localhost:8631/ >/dev/null 2>&1; do
    attempt=$((attempt+1))
    if [ "$attempt" -ge 60 ]; then echo 'Existing service did not stop.'; exit 1; fi
    sleep 1
  done
fi
if /usr/bin/curl -fsS --max-time 2 http://localhost:8631/ >/dev/null 2>&1; then
  echo 'Port 8631 is still in use. Stop the development printer service and retry.'; exit 1
fi
mkdir -p "$install_dir/bin" "$install_dir/state" "$install_dir/spool" "$install_dir/logs" "$HOME/Library/LaunchAgents"
cp "$package_dir/payload/bin/dell-printer" "$package_dir/payload/bin/foo2hbpl2" "$install_dir/bin/"
chmod 755 "$install_dir/bin/dell-printer" "$install_dir/bin/foo2hbpl2"
sh "$package_dir/prepare-icons.sh" "$install_dir/icons" "$package_dir/assets/DellC1765.icns"
if [ -d "$package_dir/Notices" ]; then ditto "$package_dir/Notices" "$install_dir/Notices"; fi
cp "$package_dir/Uninstall.command" "$install_dir/Uninstall.command"

# Optionally preserve an existing development printer's UUID/queue identity.
if [ -n "${DELL_MIGRATE_STATE:-}" ] && [ ! -e "$install_dir/state/dell-printer.state" ]; then
  awk '/^DefaultPrinterID / {$0="DefaultPrinterID 2"} /<Printer / {skip=($0 !~ /name="DellNative"/)} !skip {print} /<\/Printer>/ {skip=0}' \
    "$DELL_MIGRATE_STATE" > "$install_dir/state/dell-printer.state"
fi

tmp_plist="$install_dir/agent-new.plist"
plutil -create xml1 "$tmp_plist"
plutil -insert Label -string "$label" "$tmp_plist"
plutil -insert ProgramArguments -array "$tmp_plist"
for argument in "$install_dir/bin/dell-printer" server -o server-port=8631 \
  -o listen-hostname=localhost -o server-hostname=localhost \
  -o "spool-directory=\"$install_dir/spool\"" -o "log-file=\"$install_dir/logs/service.log\"" -o log-level=info; do
  plutil -insert ProgramArguments -string "$argument" -append "$tmp_plist"
done
plutil -insert EnvironmentVariables -dictionary "$tmp_plist"
plutil -insert EnvironmentVariables.XDG_CONFIG_HOME -string "$install_dir/state" "$tmp_plist"
plutil -insert RunAtLoad -bool true "$tmp_plist"
plutil -insert KeepAlive -bool true "$tmp_plist"
plutil -insert ThrottleInterval -integer 10 "$tmp_plist"
plutil -insert ProcessType -string Background "$tmp_plist"
plutil -insert StandardOutPath -string "$install_dir/logs/launch.log" "$tmp_plist"
plutil -insert StandardErrorPath -string "$install_dir/logs/launch-error.log" "$tmp_plist"
plutil -lint "$tmp_plist"
mv "$tmp_plist" "$agent"
launchctl bootstrap "gui/$user_id" "$agent"

attempt=0
until /usr/bin/curl -fsS --max-time 2 http://localhost:8631/ >/dev/null 2>&1; do
  attempt=$((attempt+1))
  if [ "$attempt" -ge 20 ]; then echo "Service did not start. See $install_dir/logs"; exit 1; fi
  sleep 1
done
app="$install_dir/bin/dell-printer"
if "$app" printers -u ipp://localhost:8631/ | /usr/bin/grep -q DellNative; then
  "$app" modify -d DellNative -v "socket://$printer_host:9100"
else
  "$app" add -u ipp://localhost:8631/ -d DellNative -m dell-c1765 -v "socket://$printer_host:9100"
fi
# Use Apple's AirPrint generator: it fetches printer-icons and registers a
# readable system icon. CUPS '-m everywhere' plus APPrinterIconPath alone does
# not register the artwork in Print Center on macOS 27.
airprint_ppd=$(mktemp "$install_dir/airprint-ppd.XXXXXX")
trap 'rm -f "$airprint_ppd"' EXIT HUP INT TERM
input_ppd=/dev/null
if [ -r /etc/cups/ppd/Dell_C1765nfw_Native.ppd ]; then
  input_ppd=/etc/cups/ppd/Dell_C1765nfw_Native.ppd
fi
/System/Library/Printers/Libraries/ipp2ppd \
  ipp://localhost:8631/ipp/print/DellNative "$input_ppd" > "$airprint_ppd"
# Do not replace a working queue with an empty/incomplete generated description.
/usr/bin/grep -q '^\*APAirPrint: True' "$airprint_ppd"
/usr/bin/grep -q '^\*cupsFilter2: "image/urf image/urf' "$airprint_ppd"
lpadmin -p Dell_C1765nfw_Native -E -v ipp://localhost:8631/ipp/print/DellNative \
  -P "$airprint_ppd" -D 'Dell C1765nfw Native'
rm -f "$airprint_ppd"
trap - EXIT HUP INT TERM
echo 'Installed Dell C1765nfw Native. The service starts at login and restarts if it exits.'
echo 'Select Dell C1765nfw Native in the normal macOS Print dialog.'
