#!/bin/sh
set -eu
label=local.dell-native.printer
user_id=$(id -u)
install_dir="$HOME/Library/Application Support/DellNative"
agent="$HOME/Library/LaunchAgents/$label.plist"
launchctl bootout "gui/$user_id/$label" 2>/dev/null || true
if lpstat -p Dell_C1765nfw_Native >/dev/null 2>&1; then lpadmin -x Dell_C1765nfw_Native; fi
archive="$HOME/.Trash/DellNative-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$archive"
if [ -e "$agent" ]; then mv "$agent" "$archive/"; fi
if [ -d "$install_dir" ]; then mv "$install_dir" "$archive/"; fi
echo 'Removed the native queue and background service. Files are in Trash; the Dell vendor driver is unchanged.'
