#!/bin/bash
# Double-click this after a pair leaves, or run with --yes from the workshop
# agent (no confirm dialog). Restores the starter, picks a new look, leaves
# the gallery alone.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
STARTER="$ROOT/Starter"
DESKTOP_STARTER="$HOME/Desktop/Starter"
APPLY="$ROOT/scripts/apply_seed.py"
YES=0
if [[ "${1:-}" == "--yes" ]]; then
  YES=1
fi

if [[ "$YES" -ne 1 ]]; then
  confirm="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
try
  display dialog "Reset this Mac for the next pair?

This wipes the current Xcode project, picks a new look, and clears the exercise ticks.
The gallery on the web is not touched." buttons {"Cancel", "Reset"} default button "Reset" with icon caution
  return button returned of result
on error
  return "Cancel"
end try
APPLESCRIPT
)"
  if [[ "${confirm:-Cancel}" != "Reset" ]]; then
    exit 0
  fi
fi

osascript -e 'tell application "Ambassadors26" to quit' >/dev/null 2>&1 || true
sleep 0.4

rewind_starter() {
  local dir="$1"
  if [[ ! -d "$dir/.git" ]]; then
    return 1
  fi
  local base
  base="$(git -C "$dir" rev-list --max-parents=0 HEAD)"
  git -C "$dir" reset --hard "$base" >/dev/null
  git -C "$dir" clean -fd >/dev/null
}

commit_seed() {
  local dir="$1"
  local name="$2"
  git -C "$dir" add -A
  git -C "$dir" commit --quiet -m "session seed: ${name}" || true
}

if ! rewind_starter "$STARTER"; then
  if [[ "$YES" -eq 1 ]]; then
    echo "Could not find Starter/.git — reset aborted." >&2
  else
    osascript -e 'display dialog "Could not find Starter/.git — reset aborted." buttons {"OK"} default button "OK" with icon stop'
  fi
  exit 1
fi

overlay_onto() {
  local dir="$1"
  if [[ -d "$ROOT/scripts/starter-overlay" ]]; then
    cp -R "$ROOT/scripts/starter-overlay/." "$dir/"
  fi
}

overlay_onto "$STARTER"

desktop_is_git=0
if [[ -d "$DESKTOP_STARTER" && "$DESKTOP_STARTER" != "$STARTER" ]]; then
  if rewind_starter "$DESKTOP_STARTER"; then
    desktop_is_git=1
  fi
  overlay_onto "$DESKTOP_STARTER"
fi

info="$(python3 "$APPLY" --starter "$STARTER" --print-json)"
theme_id="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$info")"
theme_name="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$info")"

if [[ -d "$DESKTOP_STARTER" && "$DESKTOP_STARTER" != "$STARTER" ]]; then
  python3 "$APPLY" --starter "$DESKTOP_STARTER" --theme "$theme_id" >/dev/null
fi

commit_seed "$STARTER" "$theme_name"
if [[ "$desktop_is_git" -eq 1 ]]; then
  commit_seed "$DESKTOP_STARTER" "$theme_name"
fi

rm -rf "$HOME/Library/Developer/Xcode/DerivedData/"*Ambassadors26* 2>/dev/null || true

find "$HOME/Desktop" -maxdepth 1 \( -name 'Screen Shot *.png' -o -name 'Screenshot *.png' \) -mtime -1 -delete 2>/dev/null || true

open "$ROOT/exercise.html#reset"

if [[ "$YES" -eq 1 ]]; then
  osascript -e "display notification \"Look: ${theme_name}. Open a new Coding Assistant chat, then Run once.\" with title \"Ready for the next pair\"" >/dev/null 2>&1 || true
else
  osascript <<APPLESCRIPT
display dialog "Ready for the next pair.

Look: ${theme_name}

Open a new Coding Assistant chat in Xcode so the last pair's thread is gone.
Then open Starter/Ambassadors26.xcodeproj and press Run once to warm the build." buttons {"OK"} default button "OK"
APPLESCRIPT
fi
