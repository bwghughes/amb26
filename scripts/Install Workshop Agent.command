#!/bin/bash
# Installs a LaunchAgent that polls the staff dashboard and runs
# Reset Workshop.command --yes when you press Reset.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PACK="$(cd "$DIR/.." && pwd)"
AGENT="$PACK/scripts/workshop-agent.py"
SUPPORT="$HOME/Library/Application Support/Ambassadors26"
PLIST="$HOME/Library/LaunchAgents/com.ambassadors26.workshop-agent.plist"
LABEL="com.ambassadors26.workshop-agent"
DEFAULT_SERVER="https://gallery-production-85f3.up.railway.app"
DEFAULT_SECRET="workshop-reset"

if [[ ! -f "$AGENT" ]]; then
  osascript -e 'display dialog "workshop-agent.py is missing from scripts/." buttons {"OK"} default button "OK" with icon stop'
  exit 1
fi

chmod +x "$AGENT" "$PACK/scripts/Reset Workshop.command" || true

choice="$(osascript <<APPLESCRIPT
try
  set theServer to text returned of (display dialog "Contest site for this Mac's agent:" default answer "${DEFAULT_SERVER}" buttons {"Cancel", "Install"} default button "Install")
  return theServer
on error
  return ""
end try
APPLESCRIPT
)"

if [[ -z "${choice}" ]]; then
  exit 0
fi

secret="$(osascript <<APPLESCRIPT
try
  set theSecret to text returned of (display dialog "Agent secret (must match AGENT_SECRET on the server). Not the event PIN." default answer "${DEFAULT_SECRET}" buttons {"Cancel", "Install"} default button "Install")
  return theSecret
on error
  return ""
end try
APPLESCRIPT
)"

if [[ -z "${secret}" ]]; then
  exit 0
fi

mkdir -p "$SUPPORT" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
python3 - "$SUPPORT/agent.json" "$choice" "$secret" "$PACK" <<'PY'
import json, sys
from pathlib import Path
path, server, secret, pack = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
cfg = {}
if path.exists():
    try:
        cfg = json.loads(path.read_text())
    except json.JSONDecodeError:
        cfg = {}
cfg["server"] = server.rstrip("/")
cfg["secret"] = secret
cfg["pack"] = pack
path.write_text(json.dumps(cfg, indent=2) + "\n")
PY

uid="$(id -u)"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>${AGENT}</string>
  </array>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/ambassadors26-agent.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/ambassadors26-agent.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/${uid}/${LABEL}" >/dev/null 2>&1 || true
launchctl unload "$PLIST" >/dev/null 2>&1 || true
if ! launchctl bootstrap "gui/${uid}" "$PLIST" 2>/dev/null; then
  launchctl load "$PLIST"
fi

name="$(scutil --get ComputerName 2>/dev/null || hostname)"
osascript <<APPLESCRIPT
display dialog "Agent is running on this Mac.

It will show up on the staff dashboard as:
${name}

Reset from /admin. This Mac must be on the network (Wi-Fi can be off during the session; a queued reset runs when it comes back)." buttons {"OK"} default button "OK"
APPLESCRIPT
