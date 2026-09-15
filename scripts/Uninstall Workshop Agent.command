#!/bin/bash
# Stops the workshop agent LaunchAgent on this Mac.
set -euo pipefail
LABEL="com.ambassadors26.workshop-agent"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
uid="$(id -u)"
launchctl bootout "gui/${uid}/${LABEL}" >/dev/null 2>&1 || true
launchctl unload "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
osascript -e 'display dialog "Workshop agent stopped on this Mac." buttons {"OK"} default button "OK"'
