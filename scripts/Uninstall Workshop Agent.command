#!/bin/bash
# Stops the workshop agent LaunchAgent on this Mac.
# Targets /Users/Ambassador even if this is run as root (MDM).
set -euo pipefail
LABEL="com.ambassadors26.workshop-agent"
DEFAULT_INSTALL_HOME="/Users/Ambassador"
DEFAULT_INSTALL_USER="Ambassador"
INSTALL_HOME="${INSTALL_HOME:-${AMBASSADOR_HOME:-$DEFAULT_INSTALL_HOME}}"
INSTALL_HOME="${INSTALL_HOME%/}"
if [[ -d "$INSTALL_HOME" ]]; then
  PLIST="$INSTALL_HOME/Library/LaunchAgents/${LABEL}.plist"
  if id -u "$DEFAULT_INSTALL_USER" >/dev/null 2>&1 && [[ "$INSTALL_HOME" == "$DEFAULT_INSTALL_HOME" ]]; then
    uid="$(id -u "$DEFAULT_INSTALL_USER")"
  else
    uid="$(stat -f '%u' "$INSTALL_HOME" 2>/dev/null || id -u)"
  fi
else
  PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
  uid="$(id -u)"
fi
launchctl asuser "$uid" launchctl bootout "gui/${uid}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootout "gui/${uid}/${LABEL}" >/dev/null 2>&1 || true
launchctl unload "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"
osascript -e 'display dialog "Workshop agent stopped on this Mac." buttons {"OK"} default button "OK"'
