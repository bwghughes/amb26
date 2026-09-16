#!/bin/bash
# Double-click this after a pair leaves, or run with --yes from the workshop
# agent (no confirm dialog). Restores the starter, picks a new look, leaves
# the gallery alone.
#
# --rescue  rewind to this pair's seed (not a new look). Used mid-session.
# --theme ID  pin a look instead of picking at random (staff).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
STARTER="$ROOT/Starter"
DESKTOP_STARTER="${DESKTOP_STARTER:-$HOME/Desktop/Starter}"
DESKTOP_STARTER="${DESKTOP_STARTER/#\~/$HOME}"
STOCK="$ROOT/scripts/starter-stock"
APPLY="$ROOT/scripts/apply_seed.py"
YES=0
RESCUE=0
THEME_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
      shift
      ;;
    --rescue)
      RESCUE=1
      shift
      ;;
    --theme)
      shift
      THEME_ID="${1:-}"
      if [[ -z "$THEME_ID" ]]; then
        echo "Missing theme id after --theme" >&2
        exit 1
      fi
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

fail() {
  local msg="$1"
  echo "$msg" >&2
  if [[ "$YES" -ne 1 ]]; then
    osascript -e "display dialog $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$msg") buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  fi
  exit 1
}

if [[ ! -d "$STOCK/Ambassadors26.xcodeproj" ]]; then
  fail "Could not find scripts/starter-stock — reset aborted."
fi
if [[ ! -f "$APPLY" ]]; then
  fail "Could not find scripts/apply_seed.py — reset aborted."
fi

if [[ "$YES" -ne 1 ]]; then
  if [[ "$RESCUE" -eq 1 ]]; then
    confirm="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
try
  display dialog "Restore this pair's seeded starter?

This rewinds the Xcode project to this session's look (not a new theme).
The gallery on the web is not touched." buttons {"Cancel", "Restore"} default button "Restore" with icon caution
  return button returned of result
on error
  return "Cancel"
end try
APPLESCRIPT
)"
    if [[ "${confirm:-Cancel}" != "Restore" ]]; then
      exit 0
    fi
  else
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
fi

looks_like_starter() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ "$(basename "$dir")" == "Starter" ]] || return 1
  [[ -d "$dir/Ambassadors26.xcodeproj" || -d "$dir/Ambassadors26" ]]
}

restore_stock() {
  local dest="$1"
  if [[ -d "$dest" ]] && ! looks_like_starter "$dest"; then
    fail "Refusing to overwrite '$dest' (not a Starter project)."
  fi
  mkdir -p "$dest"
  # Replace project files with the stock three-pane shell. --delete drops
  # pair-added sources (same idea as git clean -fd). Do not pass -x; keep
  # xcuserdata / DerivedData / the last-theme file.
  rsync -a --delete \
    --exclude .session-last-theme \
    --exclude .DS_Store \
    --exclude xcuserdata/ \
    --exclude '*.xcuserstate' \
    --exclude DerivedData/ \
    "$STOCK"/ "$dest"/
}

overlay_onto() {
  local dir="$1"
  if [[ -d "$ROOT/scripts/starter-overlay" ]]; then
    cp -R "$ROOT/scripts/starter-overlay/." "$dir/"
  fi
}

sync_desktop_from_pack() {
  if [[ -d "$DESKTOP_STARTER" && "$DESKTOP_STARTER" != "$STARTER" ]]; then
    if [[ -d "$DESKTOP_STARTER" ]] && ! looks_like_starter "$DESKTOP_STARTER"; then
      fail "Refusing to overwrite '$DESKTOP_STARTER' (not a Starter project)."
    fi
    mkdir -p "$DESKTOP_STARTER"
    rsync -a --delete \
      --exclude .DS_Store \
      --exclude xcuserdata/ \
      --exclude '*.xcuserstate' \
      --exclude DerivedData/ \
      "$STARTER"/ "$DESKTOP_STARTER"/
  fi
}

if [[ "$RESCUE" -eq 1 ]]; then
  KEEP_THEME="$(python3 "$APPLY" --starter "$STARTER" --print-current-id 2>/dev/null || true)"
  if [[ -z "$KEEP_THEME" && -d "$DESKTOP_STARTER" && "$DESKTOP_STARTER" != "$STARTER" ]]; then
    KEEP_THEME="$(python3 "$APPLY" --starter "$DESKTOP_STARTER" --print-current-id 2>/dev/null || true)"
  fi
  if [[ -z "$KEEP_THEME" ]]; then
    fail "Could not find this pair's theme (.session-last-theme or SEED.md) — rescue aborted."
  fi
  THEME_ID="$KEEP_THEME"
fi

osascript -e 'tell application "Ambassadors26" to quit' >/dev/null 2>&1 || true
sleep 0.4

restore_stock "$STARTER"
overlay_onto "$STARTER"

if [[ -n "$THEME_ID" ]]; then
  info="$(python3 "$APPLY" --starter "$STARTER" --theme "$THEME_ID" --print-json)"
else
  info="$(python3 "$APPLY" --starter "$STARTER" --print-json)"
fi
theme_id="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$info")"
theme_name="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$info")"

sync_desktop_from_pack

rm -rf "$HOME/Library/Developer/Xcode/DerivedData/"*Ambassadors26* 2>/dev/null || true

if [[ "$RESCUE" -ne 1 ]]; then
  find "$HOME/Desktop" -maxdepth 1 \( -name 'Screen Shot *.png' -o -name 'Screenshot *.png' \) -mtime -1 -delete 2>/dev/null || true

  # `open PATH#hash` looks for a file named "exercise.html#reset" and fails.
  # Pass a file: URL so the fragment reaches the page and clears the ticks.
  html="$ROOT/exercise.html"
  reset_url="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$html")#reset"
  open -u "$reset_url" 2>/dev/null || open "$html" || true
fi

if [[ "$YES" -eq 1 ]]; then
  if [[ "$RESCUE" -eq 1 ]]; then
    osascript -e "display notification \"Restored ${theme_name}. Say the sentence again.\" with title \"Seed restored\"" >/dev/null 2>&1 || true
  else
    osascript -e "display notification \"Look: ${theme_name}. Open a new Coding Assistant chat, then Run once.\" with title \"Ready for the next pair\"" >/dev/null 2>&1 || true
  fi
else
  if [[ "$RESCUE" -eq 1 ]]; then
    osascript <<APPLESCRIPT
display dialog "Restored this pair's seed.

Look: ${theme_name}

Say the sentence again." buttons {"OK"} default button "OK"
APPLESCRIPT
  else
    osascript <<APPLESCRIPT
display dialog "Ready for the next pair.

Look: ${theme_name}

Open a new Coding Assistant chat in Xcode so the last pair's thread is gone.
Then open Starter/Ambassadors26.xcodeproj and press Run once to warm the build." buttons {"OK"} default button "OK"
APPLESCRIPT
  fi
fi
