#!/bin/bash
# Double-click installer. Prompts for URL and secret (optional — skip if
# SERVER / AGENT_SECRET are already set), then runs the same non-interactive
# installer as:
#   curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash
export HOME="${HOME:-${INSTALL_HOME:-${AMBASSADOR_HOME:-/Users/Ambassador}}}"
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PACK="$(cd "$DIR/.." && pwd)"
INSTALL="$DIR/install-workshop-agent.sh"
DEFAULT_SERVER="https://ambassadors26.up.railway.app"
DEFAULT_SECRET="workshop-reset"

if [[ ! -f "$INSTALL" ]]; then
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'display dialog "install-workshop-agent.sh is missing from scripts/." buttons {"OK"} default button "OK" with icon stop'
  else
    echo "install-workshop-agent.sh is missing from scripts/." >&2
  fi
  exit 1
fi

chmod +x "$INSTALL" || true

run_install() {
  PACK="$PACK" INTERACTIVE="${INTERACTIVE:-1}" /bin/bash "$INSTALL"
}

# Env already provided: no dialogs.
if [[ -n "${SERVER:-}" && -n "${AGENT_SECRET:-}" ]]; then
  INTERACTIVE="${INTERACTIVE:-0}"
  run_install
  exit 0
fi

if ! command -v osascript >/dev/null 2>&1; then
  INTERACTIVE=0
  SERVER="${SERVER:-$DEFAULT_SERVER}" AGENT_SECRET="${AGENT_SECRET:-$DEFAULT_SECRET}" run_install
  exit 0
fi

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

SERVER="$choice" AGENT_SECRET="$secret" INTERACTIVE=1 run_install
