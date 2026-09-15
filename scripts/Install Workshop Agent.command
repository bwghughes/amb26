#!/bin/bash
# Double-click installer. Prompts for URL and secret, then runs the same
# non-interactive installer as:
#   curl -fsSL https://ambassadors26.up.railway.app/install | bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PACK="$(cd "$DIR/.." && pwd)"
INSTALL="$DIR/install-workshop-agent.sh"
DEFAULT_SERVER="https://ambassadors26.up.railway.app"
DEFAULT_SECRET="workshop-reset"

if [[ ! -f "$INSTALL" ]]; then
  osascript -e 'display dialog "install-workshop-agent.sh is missing from scripts/." buttons {"OK"} default button "OK" with icon stop'
  exit 1
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

SERVER="$choice" AGENT_SECRET="$secret" PACK="$PACK" INTERACTIVE=1 /bin/bash "$INSTALL"
