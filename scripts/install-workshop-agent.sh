#!/bin/bash
# Non-interactive installer for contest Macs. Safe to re-run. Does not reset.
#
#   curl -fsSL https://ambassadors26.up.railway.app/install | bash
#
# Optional env:
#   SERVER / CONTEST_URL   contest site (default https://ambassadors26.up.railway.app)
#   AGENT_SECRET           must match the server (default workshop-reset)
#   PACK                   existing Ambassadors26-CodeAlong folder
#   PACK_REMOTE            git URL if the pack is not on disk yet
set -euo pipefail

DEFAULT_SERVER="https://ambassadors26.up.railway.app"
DEFAULT_SECRET="workshop-reset"
DEFAULT_REMOTE="https://github.com/bwghughes/amb26.git"
DEFAULT_PACK="$HOME/Desktop/Ambassadors26-CodeAlong"
LABEL="com.ambassadors26.workshop-agent"
SUPPORT="$HOME/Library/Application Support/Ambassadors26"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

SERVER="${SERVER:-${CONTEST_URL:-$DEFAULT_SERVER}}"
SECRET="${AGENT_SECRET:-$DEFAULT_SECRET}"
REMOTE="${PACK_REMOTE:-$DEFAULT_REMOTE}"

expand_path() {
  local value="$1"
  value="${value/#\~/$HOME}"
  echo "$value"
}

looks_like_pack() {
  local dir="$1"
  [[ -f "$dir/scripts/workshop-agent.py" && -f "$dir/scripts/Reset Workshop.command" ]]
}

find_existing_pack() {
  local candidates=()
  local script_dir=""

  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    candidates+=("$(cd "$script_dir/.." && pwd)")
    candidates+=("$script_dir")
  fi

  candidates+=(
    "$HOME/Desktop/Ambassadors26-CodeAlong"
    "$HOME/code/Ambassadors26-CodeAlong"
    "$HOME/Ambassadors26-CodeAlong"
  )

  local c
  for c in "${candidates[@]}"; do
    if looks_like_pack "$c"; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

update_pack() {
  local dir="$1"
  if [[ ! -d "$dir/.git" ]]; then
    echo "Using existing pack at $dir (not a git checkout; left as-is)."
    return 0
  fi
  if git -C "$dir" pull --ff-only >/dev/null 2>&1; then
    echo "Updated pack at $dir"
  else
    echo "Using existing pack at $dir (git pull skipped)."
  fi
}

clone_failed() {
  echo "Could not clone $REMOTE" >&2
  echo "If that repo is private, copy Ambassadors26-CodeAlong onto this Mac and re-run with PACK set:" >&2
  echo "  PACK=$DEFAULT_PACK curl -fsSL ${DEFAULT_SERVER}/install | bash" >&2
  echo "Common locations: ~/Desktop/Ambassadors26-CodeAlong, ~/code/Ambassadors26-CodeAlong" >&2
  exit 1
}

if [[ -n "${PACK:-}" ]]; then
  PACK="$(expand_path "$PACK")"
  if looks_like_pack "$PACK"; then
    update_pack "$PACK"
  else
    echo "PACK=$PACK is missing scripts/workshop-agent.py (and Reset Workshop.command)." >&2
    echo "Point PACK at the Ambassadors26-CodeAlong folder, or unset it to clone." >&2
    exit 1
  fi
elif PACK="$(find_existing_pack)"; then
  update_pack "$PACK"
else
  if ! command -v git >/dev/null 2>&1; then
    clone_failed
  fi
  mkdir -p "$(dirname "$DEFAULT_PACK")"
  if [[ -e "$DEFAULT_PACK" ]]; then
    echo "Refusing to clone into $DEFAULT_PACK because it already exists and is not a workshop pack." >&2
    clone_failed
  fi
  echo "Cloning $REMOTE -> $DEFAULT_PACK"
  git clone "$REMOTE" "$DEFAULT_PACK" || clone_failed
  PACK="$DEFAULT_PACK"
fi

AGENT="$PACK/scripts/workshop-agent.py"
if [[ ! -f "$AGENT" ]]; then
  echo "workshop-agent.py is missing from $PACK/scripts/." >&2
  exit 1
fi

chmod +x "$AGENT" "$PACK/scripts/Reset Workshop.command" || true

mkdir -p "$SUPPORT" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
python3 - "$SUPPORT/agent.json" "$SERVER" "$SECRET" "$PACK" <<'PY'
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
echo
echo "Workshop agent installed."
echo "Pack:    $PACK"
echo "Server:  ${SERVER%/}"
echo
echo "Computer Name: $name"
echo "Confirm this Mac on ${SERVER%/}/admin under Workshop Macs."
echo "This installer does not reset the workshop."
echo

if [[ "${INTERACTIVE:-0}" == "1" ]] && command -v osascript >/dev/null 2>&1; then
  osascript <<APPLESCRIPT
display dialog "Agent is running on this Mac.

It will show up on the staff dashboard as:
${name}

Reset from /admin. This Mac must be on the network (Wi-Fi can be off during the session; a queued reset runs when it comes back)." buttons {"OK"} default button "OK"
APPLESCRIPT
fi
