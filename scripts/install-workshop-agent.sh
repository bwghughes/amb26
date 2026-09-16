#!/bin/bash
# From-scratch bootstrap for a contest Mac that already has Xcode.
# Clones the pack if needed, materializes Starter/, copies
# /Users/Ambassador/Desktop/Starter on first install, and installs the
# workshop LaunchAgent. Does not reset.
#
# Contest paths are pinned to /Users/Ambassador (not $HOME). MDM often
# runs this as root, where $HOME is /var/root — never install there.
#
#   curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash
#
# This file in the GitHub repo is the source of truth. The contest site
# redirects GET /install to that raw URL so old curl lines still work.
#
# Optional env:
#   SERVER / CONTEST_URL   contest site (default https://ambassadors26.up.railway.app)
#   AGENT_SECRET           must match the server (default workshop-reset)
#   INSTALL_HOME / AMBASSADOR_HOME
#                          install home (default /Users/Ambassador). Rehearsal override.
#   PACK                   existing Ambassadors26-CodeAlong folder (clone here if missing)
#                          default: /Users/Ambassador/Desktop/Ambassadors26-CodeAlong
#   DESKTOP_STARTER        Desktop copy of Starter (default /Users/Ambassador/Desktop/Starter)
#   REPO_URL / PACK_REMOTE git URL (default https://github.com/bwghughes/amb26.git)
# Codex API key comes from MDM on the Mac (not from this curl). Read at runtime:
#   OPENAI_API_KEY / CODEX_API_KEY in process env, launchctl getenv, or
#   managed prefs domain com.openai.codex. Never written into this script.

# Contest Mac home. Resolve and export HOME *before* `set -u`. MDM LaunchDaemons
# often spawn bash with HOME unset; expanding $HOME then aborts at line ~25.
DEFAULT_INSTALL_HOME="/Users/Ambassador"
DEFAULT_INSTALL_USER="Ambassador"
INSTALL_HOME="${INSTALL_HOME:-${AMBASSADOR_HOME:-$DEFAULT_INSTALL_HOME}}"
INSTALL_HOME="${INSTALL_HOME%/}"
export HOME="$INSTALL_HOME"

set -euo pipefail

DEFAULT_SERVER="https://ambassadors26.up.railway.app"
DEFAULT_SECRET="workshop-reset"
DEFAULT_REMOTE="https://github.com/bwghughes/amb26.git"
GITHUB_INSTALL="https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh"
LABEL="com.ambassadors26.workshop-agent"
PYTHON="/usr/bin/python3"

SERVER="${SERVER:-${CONTEST_URL:-$DEFAULT_SERVER}}"
SECRET="${AGENT_SECRET:-$DEFAULT_SECRET}"
REMOTE="${REPO_URL:-${PACK_REMOTE:-$DEFAULT_REMOTE}}"

if [[ ! -d "$INSTALL_HOME" ]]; then
  echo "Install home $INSTALL_HOME does not exist." >&2
  echo "MDM must create the contest user first (default account: $DEFAULT_INSTALL_USER, home: $DEFAULT_INSTALL_HOME)." >&2
  echo "This script will not write into /var/root or \$HOME." >&2
  echo "For rehearsal on another account, set INSTALL_HOME to that user's home." >&2
  exit 1
fi

resolve_install_user() {
  local home_owner="" dscl_user="" candidate=""
  if [[ -n "${INSTALL_USER:-}" ]] && id -u "$INSTALL_USER" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$INSTALL_HOME" == "$DEFAULT_INSTALL_HOME" ]] && id -u "$DEFAULT_INSTALL_USER" >/dev/null 2>&1; then
    INSTALL_USER="$DEFAULT_INSTALL_USER"
    return 0
  fi
  dscl_user="$(dscl . -search /Users NFSHomeDirectory "$INSTALL_HOME" 2>/dev/null | awk '{print $1; exit}' || true)"
  if [[ -n "$dscl_user" ]] && id -u "$dscl_user" >/dev/null 2>&1; then
    INSTALL_USER="$dscl_user"
    return 0
  fi
  candidate="$(basename "$INSTALL_HOME")"
  if id -u "$candidate" >/dev/null 2>&1; then
    INSTALL_USER="$candidate"
    return 0
  fi
  home_owner="$(stat -f '%Su' "$INSTALL_HOME" 2>/dev/null || true)"
  if [[ -n "$home_owner" && "$home_owner" != "root" ]] && id -u "$home_owner" >/dev/null 2>&1; then
    INSTALL_USER="$home_owner"
    return 0
  fi
  echo "Could not resolve the macOS account for install home $INSTALL_HOME." >&2
  echo "Expected user $DEFAULT_INSTALL_USER (id -u $DEFAULT_INSTALL_USER). MDM must create that account." >&2
  exit 1
}

resolve_install_user
INSTALL_UID="$(id -u "$INSTALL_USER")"
INSTALL_GROUP="$(id -gn "$INSTALL_USER")"
export HOME="$INSTALL_HOME"
export INSTALL_HOME INSTALL_USER INSTALL_UID

DEFAULT_PACK="$INSTALL_HOME/Desktop/Ambassadors26-CodeAlong"
SUPPORT="$INSTALL_HOME/Library/Application Support/Ambassadors26"
LOG="$INSTALL_HOME/Library/Logs/ambassadors26-agent.log"
PLIST="$INSTALL_HOME/Library/LaunchAgents/${LABEL}.plist"

expand_path() {
  local value="$1"
  value="${value/#\~/$INSTALL_HOME}"
  echo "$value"
}

# SIP/TCC forbids chown of ~/Desktop (and similar protected home folders).
# Never chown those directories. Only chown trees we create inside them.
is_protected_home_path() {
  local path="${1%/}"
  case "$path" in
    "$INSTALL_HOME"|"$INSTALL_HOME/Desktop"|"$INSTALL_HOME/Documents"|"$INSTALL_HOME/Downloads"|"$INSTALL_HOME/Pictures"|"$INSTALL_HOME/Movies"|"$INSTALL_HOME/Music"|"$INSTALL_HOME/Public"|"$INSTALL_HOME/Library")
      return 0
      ;;
  esac
  return 1
}

own_tree() {
  local path="$1"
  if is_protected_home_path "$path"; then
    return 0
  fi
  if [[ "$(id -u)" -eq 0 && -e "$path" ]]; then
    chown -R "${INSTALL_USER}:${INSTALL_GROUP}" "$path"
  fi
}

ensure_owned_dir() {
  local dir="$1"
  local mode="${2:-755}"
  if is_protected_home_path "$dir"; then
    [[ -d "$dir" ]] || mkdir -p "$dir"
    return 0
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    install -d -o "$INSTALL_USER" -g "$INSTALL_GROUP" -m "$mode" "$dir"
  else
    mkdir -p "$dir"
    chmod "$mode" "$dir" 2>/dev/null || true
  fi
}

# Run as the contest user so Keychain, defaults, and LaunchAgents hit their
# login session, not root's. launchctl asuser covers the Aqua domain.
as_install_user() {
  if [[ "$(id -u)" == "$INSTALL_UID" ]]; then
    env HOME="$INSTALL_HOME" USER="$INSTALL_USER" LOGNAME="$INSTALL_USER" "$@"
    return
  fi
  if [[ "$(id -u)" -ne 0 ]]; then
    sudo -u "$INSTALL_USER" env HOME="$INSTALL_HOME" USER="$INSTALL_USER" LOGNAME="$INSTALL_USER" "$@"
    return
  fi
  # Root: prefer the user's Aqua session so Keychain / defaults / launchctl
  # hit their login domain. Fall back to sudo -u if they are not logged in.
  if launchctl asuser "$INSTALL_UID" true >/dev/null 2>&1; then
    launchctl asuser "$INSTALL_UID" sudo -u "$INSTALL_USER" env HOME="$INSTALL_HOME" USER="$INSTALL_USER" LOGNAME="$INSTALL_USER" "$@"
    return
  fi
  sudo -u "$INSTALL_USER" env HOME="$INSTALL_HOME" USER="$INSTALL_USER" LOGNAME="$INSTALL_USER" "$@"
}

bootstrap_agent() {
  local domain="gui/${INSTALL_UID}"
  local target="${domain}/${LABEL}"
  if [[ "$(id -u)" -eq 0 ]]; then
    launchctl asuser "$INSTALL_UID" launchctl bootout "$target" >/dev/null 2>&1 || true
    launchctl bootout "$target" >/dev/null 2>&1 || true
    if launchctl asuser "$INSTALL_UID" launchctl bootstrap "$domain" "$PLIST"; then
      return 0
    fi
    if launchctl bootstrap "$domain" "$PLIST"; then
      return 0
    fi
    echo "LaunchAgent plist is at $PLIST (owned by $INSTALL_USER)." >&2
    echo "Could not bootstrap ${target}. It will load when $INSTALL_USER logs in." >&2
    echo "Did not load the agent into the root domain." >&2
    return 0
  fi
  launchctl bootout "$target" >/dev/null 2>&1 || true
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  if ! launchctl bootstrap "$domain" "$PLIST" 2>/dev/null; then
    launchctl load "$PLIST"
  fi
}

need_tools() {
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "No developer tools selected. Open Xcode.app once, or run: xcode-select --install" >&2
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "git is not available. Open Xcode.app once, or run: xcode-select --install" >&2
    exit 1
  fi
  if [[ ! -x "$PYTHON" ]]; then
    echo "/usr/bin/python3 is not available. Open Xcode.app once, or run: xcode-select --install" >&2
    exit 1
  fi
}

looks_like_pack() {
  local dir="$1"
  [[ -f "$dir/scripts/workshop-agent.py" && -f "$dir/scripts/Reset Workshop.command" ]]
}

looks_like_starter() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -d "$dir/Ambassadors26.xcodeproj" || -d "$dir/Ambassadors26" ]]
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
    "$INSTALL_HOME/Desktop/Ambassadors26-CodeAlong"
    "$INSTALL_HOME/code/Ambassadors26-CodeAlong"
    "$INSTALL_HOME/Ambassadors26-CodeAlong"
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
  own_tree "$dir"
}

clone_failed() {
  echo "Could not clone $REMOTE" >&2
  echo "If that repo is private, copy Ambassadors26-CodeAlong onto this Mac and re-run with PACK set:" >&2
  echo "  PACK=$DEFAULT_PACK curl -fsSL ${GITHUB_INSTALL} | bash" >&2
  echo "Or set REPO_URL to a reachable git remote." >&2
  echo "Common locations: $INSTALL_HOME/Desktop/Ambassadors26-CodeAlong, $INSTALL_HOME/code/Ambassadors26-CodeAlong" >&2
  exit 1
}

clone_into() {
  local dest="$1"
  local parent
  if [[ -e "$dest" ]]; then
    echo "Refusing to clone into $dest because it already exists and is not a workshop pack." >&2
    clone_failed
  fi
  parent="$(dirname "$dest")"
  # Parent is often ~/Desktop — create it if missing, but never chown Desktop.
  if [[ ! -d "$parent" ]]; then
    mkdir -p "$parent"
  fi
  echo "Cloning $REMOTE -> $dest"
  # Clone as Ambassador so the pack is born owned correctly (no chown of Desktop).
  if [[ "$(id -u)" -eq 0 ]]; then
    if ! as_install_user git clone "$REMOTE" "$dest"; then
      git clone "$REMOTE" "$dest" || clone_failed
    fi
  else
    git clone "$REMOTE" "$dest" || clone_failed
  fi
  own_tree "$dest"
}

# GitHub may still have Starter as a leftover gitlink (mode 160000) with no
# .gitmodules. Clone then leaves an empty folder. Prefer a real project,
# then submodule, then scripts/starter-stock. Do not run apply_seed / reset.
ensure_starter() {
  local starter="$PACK/Starter"
  local stock="$PACK/scripts/starter-stock"
  local overlay="$PACK/scripts/starter-overlay"

  if looks_like_starter "$starter"; then
    echo "Starter project is present at $starter"
    return 0
  fi

  echo "Starter/ is missing or not a real Xcode project (empty gitlink after clone is common)."

  if [[ -d "$PACK/.git" ]]; then
    git -C "$PACK" submodule update --init --recursive -- Starter >/dev/null 2>&1 || true
    if looks_like_starter "$starter"; then
      echo "Initialized Starter from git submodule."
      return 0
    fi
  fi

  if ! looks_like_starter "$stock"; then
    echo "Could not materialize Starter/." >&2
    echo "scripts/starter-stock is missing, and Starter is not a usable project (broken gitlink / no submodule URL)." >&2
    echo "Copy the full Ambassadors26-CodeAlong folder onto this Mac and re-run with PACK set." >&2
    exit 1
  fi

  rm -rf "$starter"
  mkdir -p "$starter"
  rsync -a --exclude .DS_Store "$stock"/ "$starter"/
  if [[ -d "$overlay" ]]; then
    cp -R "$overlay/." "$starter/"
  fi
  echo "Copied Starter from scripts/starter-stock."
}

chmod_scripts() {
  local dir="$PACK/scripts"
  local f
  for f in \
    "Reset Workshop.command" \
    "Rescue Session.command" \
    "Install Workshop Agent.command" \
    "Uninstall Workshop Agent.command" \
    "install-workshop-agent.sh" \
    "workshop-agent.py" \
    "apply_seed.py"
  do
    if [[ -f "$dir/$f" ]]; then
      chmod +x "$dir/$f"
    fi
  done
}

# First install: create /Users/Ambassador/Desktop/Starter so pairs open that project.
# Re-run: leave an existing Desktop copy alone (a pair may be mid-session).
# Override with DESKTOP_STARTER.
ensure_desktop_starter() {
  local src="$PACK/Starter"
  DESKTOP_NOTE="Open $src/Ambassadors26.xcodeproj in Xcode."

  if [[ "$src" == "$DESKTOP_STARTER" ]]; then
    DESKTOP_NOTE="Open $DESKTOP_STARTER/Ambassadors26.xcodeproj in Xcode."
    return 0
  fi

  if [[ -d "$DESKTOP_STARTER" ]] && looks_like_starter "$DESKTOP_STARTER"; then
    echo "Leaving existing $DESKTOP_STARTER in place."
    DESKTOP_NOTE="Open $DESKTOP_STARTER/Ambassadors26.xcodeproj in Xcode."
    return 0
  fi

  if [[ -e "$DESKTOP_STARTER" ]] && ! looks_like_starter "$DESKTOP_STARTER"; then
    local leftover
    leftover="$(find "$DESKTOP_STARTER" -mindepth 1 -maxdepth 1 ! -name '.DS_Store' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$leftover" != "0" ]]; then
      echo "Refusing to overwrite $DESKTOP_STARTER (not a Starter project)." >&2
      return 0
    fi
  fi

  # Do not chown ~/Desktop. Create Starter inside it with Ambassador ownership.
  mkdir -p "$(dirname "$DESKTOP_STARTER")"
  if [[ "$(id -u)" -eq 0 ]]; then
    install -d -o "$INSTALL_USER" -g "$INSTALL_GROUP" "$DESKTOP_STARTER"
  else
    mkdir -p "$DESKTOP_STARTER"
  fi
  rsync -a \
    --exclude .DS_Store \
    --exclude xcuserdata/ \
    --exclude '*.xcuserstate' \
    --exclude DerivedData/ \
    "$src"/ "$DESKTOP_STARTER"/
  own_tree "$DESKTOP_STARTER"
  echo "Copied Starter to $DESKTOP_STARTER"
  DESKTOP_NOTE="Open $DESKTOP_STARTER/Ambassadors26.xcodeproj in Xcode."
}

xcode_app_path() {
  local developer app
  developer="$(xcode-select -p)"
  app="$(cd "$developer/../.." && pwd)"
  echo "$app"
}

# MDM / login-item env is often on the Aqua session, not in this shell.
# Official Codex MDM domain is com.openai.codex (config_toml_base64, plus
# any OPENAI_API_KEY / CODEX_API_KEY keys staff put on that payload).
# Prints "source<TAB>key" to stdout; never log the key.
resolve_codex_api_key() {
  "$PYTHON" - <<'PY'
import os
import plistlib
import subprocess
import sys
from pathlib import Path

KEY_NAMES = (
    "OPENAI_API_KEY",
    "CODEX_API_KEY",
    "openai_api_key",
    "codex_api_key",
    "APIKey",
    "api_key",
)

def nonempty(value):
    if value is None:
        return None
    if isinstance(value, bytes):
        try:
            value = value.decode()
        except UnicodeDecodeError:
            return None
    if not isinstance(value, str):
        return None
    value = value.strip()
    return value or None

def emit(source, value):
    sys.stdout.write(source + "\t" + value)
    sys.exit(0)

for name in ("OPENAI_API_KEY", "CODEX_API_KEY"):
    found = nonempty(os.environ.get(name))
    if found:
        emit("process env " + name, found)

uid = os.environ.get("INSTALL_UID", "")
for name in ("OPENAI_API_KEY", "CODEX_API_KEY"):
    commands = [["launchctl", "getenv", name]]
    if uid:
        commands.append(["launchctl", "asuser", uid, "launchctl", "getenv", name])
    for cmd in commands:
        try:
            raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        found = nonempty(raw.decode() if raw else "")
        if found:
            emit("launchctl getenv " + name, found)

def defaults_read(domain, key):
    try:
        raw = subprocess.check_output(
            ["defaults", "read", domain, key], stderr=subprocess.DEVNULL
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return nonempty(raw.decode() if raw else "")

for domain in ("com.openai.codex", "com.apple.dt.Xcode"):
    for name in KEY_NAMES:
        found = defaults_read(domain, name)
        if found:
            emit("managed prefs " + domain + " " + name, found)

user = os.environ.get("INSTALL_USER") or os.environ.get("USER", "")
install_home = os.environ.get("INSTALL_HOME", "")
roots = [
    Path("/Library/Managed Preferences"),
    Path("/Library/Managed Preferences") / user if user else None,
    Path(install_home) / "Library/Managed Preferences" if install_home else None,
]
seen = set()
for root in roots:
    if root is None or not root.is_dir():
        continue
    for path in root.rglob("*.plist"):
        resolved = str(path.resolve()) if path.exists() else str(path)
        if resolved in seen:
            continue
        seen.add(resolved)
        try:
            data = plistlib.loads(path.read_bytes())
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        for name in KEY_NAMES:
            found = nonempty(data.get(name))
            if found:
                emit("MDM plist " + path.name + " " + name, found)

sys.exit(1)
PY
}

warn_codex() {
  echo "WARNING: $*" >&2
}

# Official Xcode Intelligence path: AgentVersions.plist names the Codex
# tarball, Xcode loads it from /Users/Ambassador/Library/Developer/Xcode/CodingAssistant.
# Missing MDM key or Codex setup must not fail pack + LaunchAgent.
install_xcode_codex() {
  local key="" source="" resolved=""
  if resolved="$(resolve_codex_api_key)"; then
    source="${resolved%%$'\t'*}"
    key="${resolved#*$'\t'}"
  fi

  local app plist version_plist
  if ! app="$(xcode_app_path)"; then
    warn_codex "Could not resolve Xcode.app from xcode-select. Pack and workshop agent are installed."
    CODEX_STATUS="skipped (no Xcode.app)"
    return 0
  fi
  plist="$app/Contents/PlugIns/IDEIntelligenceChat.framework/Resources/AgentVersions.plist"
  if [[ ! -f "$plist" ]]; then
    plist="$app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/Current/Resources/AgentVersions.plist"
  fi
  version_plist="$app/Contents/version.plist"
  if [[ ! -f "$plist" ]]; then
    warn_codex "This Xcode has no Intelligence AgentVersions.plist. Install Xcode 27+ (full app) and re-run."
    CODEX_STATUS="skipped (no Xcode Intelligence)"
    return 0
  fi

  local url checksum version name build arch
  url="$(/usr/libexec/PlistBuddy -c 'Print :codex:url' "$plist" 2>/dev/null || true)"
  checksum="$(/usr/libexec/PlistBuddy -c 'Print :codex:checksum' "$plist" 2>/dev/null || true)"
  version="$(/usr/libexec/PlistBuddy -c 'Print :codex:version' "$plist" 2>/dev/null || true)"
  name="$(/usr/libexec/PlistBuddy -c 'Print :codex:name' "$plist" 2>/dev/null || true)"
  build="$(/usr/libexec/PlistBuddy -c 'Print :ProductBuildVersion' "$version_plist" 2>/dev/null || true)"
  if [[ -z "$url" || -z "$version" || -z "$name" ]]; then
    warn_codex "Xcode Intelligence AgentVersions.plist has no Codex entry. Skipping Codex."
    CODEX_STATUS="skipped (no Codex in this Xcode)"
    return 0
  fi
  if [[ -z "$build" ]]; then
    warn_codex "Could not read Xcode ProductBuildVersion from $version_plist"
    CODEX_STATUS="skipped (no Xcode build id)"
    return 0
  fi

  arch="$(uname -m)"
  local verify_checksum=1
  if [[ "$arch" == "x86_64" && "$url" == *aarch64-apple-darwin* ]]; then
    url="${url/aarch64-apple-darwin/x86_64-apple-darwin}"
    verify_checksum=0
  elif [[ "$arch" == "arm64" && "$url" == *x86_64-apple-darwin* ]]; then
    url="${url/x86_64-apple-darwin/aarch64-apple-darwin}"
    verify_checksum=0
  fi

  local agents_root dest xcode_link work tgz extracted dest_bin
  agents_root="$INSTALL_HOME/Library/Developer/Xcode/CodingAssistant/Agents"
  dest="$agents_root/codex/$version"
  dest_bin="$dest/codex"
  xcode_link="$agents_root/XcodeVersions/$build/codex"
  local skip_download=0
  if [[ -x "$dest_bin" && -f "$dest/Info.plist" ]]; then
    local existing
    existing="$(/usr/libexec/PlistBuddy -c 'Print :checksum' "$dest/Info.plist" 2>/dev/null || true)"
    if [[ -n "$checksum" && "$existing" == "$checksum" && "$verify_checksum" == "1" ]]; then
      skip_download=1
    elif [[ "$verify_checksum" == "0" && -x "$dest_bin" ]]; then
      skip_download=1
    fi
  fi

  if [[ "$skip_download" == "0" ]]; then
    echo "Downloading Codex $version for Xcode Intelligence…"
    work="$(mktemp -d "${TMPDIR:-/tmp}/amb26-codex.XXXXXX")"
    tgz="$work/codex.tar.gz"
    if ! curl -fsSL -o "$tgz" "$url"; then
      rm -rf "$work"
      warn_codex "Could not download the Codex agent tarball. Pack and workshop agent are installed. Re-run later."
      CODEX_STATUS="skipped (download failed)"
      return 0
    fi
    if [[ "$verify_checksum" == "1" && -n "$checksum" ]]; then
      local got
      got="$(shasum -a 512 "$tgz" | awk '{print $1}')"
      if [[ "$got" != "$checksum" ]]; then
        rm -rf "$work"
        warn_codex "Codex download checksum mismatch. Skipping Codex."
        CODEX_STATUS="skipped (checksum mismatch)"
        return 0
      fi
    else
      checksum="$(shasum -a 512 "$tgz" | awk '{print $1}')"
    fi
    mkdir -p "$work/extracted"
    if ! tar -xzf "$tgz" -C "$work/extracted"; then
      rm -rf "$work"
      warn_codex "Could not extract the Codex tarball. Skipping Codex."
      CODEX_STATUS="skipped (extract failed)"
      return 0
    fi
    extracted="$(find "$work/extracted" -type f \( -name 'codex' -o -name 'codex-*-apple-darwin' \) -print -quit)"
    if [[ -z "$extracted" ]]; then
      extracted="$(find "$work/extracted" -type f -perm +111 -print -quit)"
    fi
    if [[ -z "$extracted" || ! -f "$extracted" ]]; then
      rm -rf "$work"
      warn_codex "Codex tarball had no executable. Skipping Codex."
      CODEX_STATUS="skipped (bad tarball)"
      return 0
    fi
    ensure_owned_dir "$dest"
    cp "$extracted" "$dest_bin"
    chmod +x "$dest_bin"
    xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
    rm -rf "$work"
    cat > "$dest/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>checksum</key>
	<string>${checksum}</string>
	<key>name</key>
	<string>${name}</string>
	<key>url</key>
	<string>${url}</string>
	<key>version</key>
	<string>${version}</string>
</dict>
</plist>
EOF
  else
    echo "Codex $version already installed for Xcode Intelligence."
  fi

  ensure_owned_dir "$agents_root/XcodeVersions/$build"
  ln -sfn "$dest" "$xcode_link"
  own_tree "$INSTALL_HOME/Library/Developer/Xcode/CodingAssistant"

  local codex_home config
  codex_home="$INSTALL_HOME/Library/Developer/Xcode/CodingAssistant/codex"
  ensure_owned_dir "$codex_home" 700
  config="$codex_home/config.toml"
  "$PYTHON" - "$config" "$PACK/Starter" "$DESKTOP_STARTER" <<'PY'
from pathlib import Path
import re
import sys

config_path = Path(sys.argv[1])
starters = [p for p in sys.argv[2:] if p]
text = config_path.read_text() if config_path.exists() else ""
if re.search(r"(?m)^cli_auth_credentials_store\s*=", text):
    text = re.sub(
        r"(?m)^cli_auth_credentials_store\s*=\s*.*$",
        'cli_auth_credentials_store = "keyring"',
        text,
        count=1,
    )
else:
    prefix = 'cli_auth_credentials_store = "keyring"\n'
    text = prefix + text if text else prefix
for starter in starters:
    marker = f'[projects."{starter}"]'
    if marker not in text:
        text = text.rstrip() + f"\n\n{marker}\ntrust_level = \"trusted\"\n"
config_path.write_text(text if text.endswith("\n") else text + "\n")
PY

  as_install_user defaults write com.apple.dt.Xcode IDEChatAllowAgents -bool YES
  as_install_user defaults write com.apple.dt.Xcode IDEAllowUnauthenticatedAgents -bool YES
  as_install_user defaults write com.apple.dt.Xcode IDEIntelligenceHasInstalledAtLeastOnce -bool YES
  as_install_user "$PYTHON" - <<'PY'
import json
import subprocess

payload = json.dumps(
    {
        "modelIdentifier": "codex",
        "providerIdentifier": {"builtIn": {"_0": {"gms": {}}}},
    },
    separators=(",", ":"),
).encode()
subprocess.check_call(
    [
        "defaults",
        "write",
        "com.apple.dt.Xcode",
        "IDEChatUserSelectedDefaultChatModelDefinitionIdentifier",
        "-data",
        payload.hex(),
    ]
)
PY

  if [[ -z "$key" ]]; then
    echo
    warn_codex "MDM has not delivered a Codex API key yet."
    warn_codex "Put OPENAI_API_KEY or CODEX_API_KEY on the Mac via MDM, then re-run:"
    warn_codex "  curl -fsSL ${GITHUB_INSTALL} | bash"
    warn_codex "MDM destinations this script reads (first match wins):"
    warn_codex "  1. process environment OPENAI_API_KEY / CODEX_API_KEY"
    warn_codex "  2. launchctl getenv OPENAI_API_KEY / CODEX_API_KEY  (GUI / config-profile env)"
    warn_codex "  3. managed prefs domain com.openai.codex, same key names"
    warn_codex "  4. any /Library/Managed Preferences plist with those keys"
    warn_codex "Pack and workshop agent are installed. Codex binary is in place; login was skipped."
    CODEX_STATUS="agent installed; waiting for MDM API key"
    return 0
  fi

  # Official Codex login: key on stdin, stored in the contest user's Keychain
  # "Codex Auth" (and auth.json if the CLI also writes one). Run as Ambassador
  # so the item lands in their login keychain, not root's. Never print the key.
  if ! printf '%s' "$key" | as_install_user env CODEX_HOME="$codex_home" "$dest_bin" login --with-api-key >/dev/null; then
    warn_codex "codex login --with-api-key failed. MDM delivered a key from: $source"
    warn_codex "Pack and workshop agent are installed. Re-run after MDM refreshes the key."
    unset key
    CODEX_STATUS="agent installed; login failed"
    return 0
  fi
  if [[ -f "$codex_home/auth.json" ]]; then
    chmod 600 "$codex_home/auth.json"
  fi
  own_tree "$codex_home"

  # Bridge into Ambassador's Aqua session so Xcode (Dock / GUI) can see the
  # same key if MDM only wrote managed prefs or a root-only env.
  user_openai="$(launchctl asuser "$INSTALL_UID" launchctl getenv OPENAI_API_KEY 2>/dev/null || true)"
  user_codex="$(launchctl asuser "$INSTALL_UID" launchctl getenv CODEX_API_KEY 2>/dev/null || true)"
  if [[ "$(id -u)" == "$INSTALL_UID" ]]; then
    user_openai="${user_openai:-$(launchctl getenv OPENAI_API_KEY 2>/dev/null || true)}"
    user_codex="${user_codex:-$(launchctl getenv CODEX_API_KEY 2>/dev/null || true)}"
  fi
  if [[ -z "$user_openai" ]]; then
    if [[ "$(id -u)" == "$INSTALL_UID" ]]; then
      launchctl setenv OPENAI_API_KEY "$key"
    else
      launchctl asuser "$INSTALL_UID" launchctl setenv OPENAI_API_KEY "$key" 2>/dev/null || true
    fi
  fi
  if [[ -z "$user_codex" ]]; then
    if [[ "$(id -u)" == "$INSTALL_UID" ]]; then
      launchctl setenv CODEX_API_KEY "$key"
    else
      launchctl asuser "$INSTALL_UID" launchctl setenv CODEX_API_KEY "$key" 2>/dev/null || true
    fi
  fi
  unset key

  echo "Codex is the Xcode Intelligence agent. API key taken from MDM ($source) and stored in $INSTALL_USER's login keychain (service: Codex Auth), not in the git repo."
  CODEX_STATUS="configured from MDM ($source)"
}

need_tools

DESKTOP_STARTER="$(expand_path "${DESKTOP_STARTER:-$INSTALL_HOME/Desktop/Starter}")"

if [[ -n "${PACK:-}" ]]; then
  PACK="$(expand_path "$PACK")"
  if looks_like_pack "$PACK"; then
    update_pack "$PACK"
  elif [[ ! -e "$PACK" ]]; then
    clone_into "$PACK"
  else
    echo "PACK=$PACK is missing scripts/workshop-agent.py (and Reset Workshop.command)." >&2
    echo "Point PACK at the Ambassadors26-CodeAlong folder, or unset it to clone." >&2
    exit 1
  fi
elif PACK="$(find_existing_pack)"; then
  update_pack "$PACK"
else
  clone_into "$DEFAULT_PACK"
  PACK="$DEFAULT_PACK"
fi

AGENT="$PACK/scripts/workshop-agent.py"
if [[ ! -f "$AGENT" ]]; then
  echo "workshop-agent.py is missing from $PACK/scripts/." >&2
  exit 1
fi

ensure_starter
chmod_scripts
ensure_desktop_starter
if [[ "$PACK" == "$INSTALL_HOME"/* || "$PACK" == "$INSTALL_HOME" ]]; then
  own_tree "$PACK"
fi

ensure_owned_dir "$INSTALL_HOME/Library/Application Support"
ensure_owned_dir "$SUPPORT" 700
ensure_owned_dir "$(dirname "$PLIST")"
ensure_owned_dir "$(dirname "$LOG")"
"$PYTHON" - "$SUPPORT/agent.json" "$SERVER" "$SECRET" "$PACK" <<'PY'
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
chmod 600 "$SUPPORT/agent.json" 2>/dev/null || true
own_tree "$SUPPORT"

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
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${INSTALL_HOME}</string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>${AGENT}</string>
  </array>
  <key>StandardOutPath</key>
  <string>${LOG}</string>
  <key>StandardErrorPath</key>
  <string>${LOG}</string>
</dict>
</plist>
EOF
chmod 644 "$PLIST" 2>/dev/null || true
own_tree "$PLIST"
touch "$LOG"
chmod 644 "$LOG" 2>/dev/null || true
own_tree "$LOG"

bootstrap_agent

install_xcode_codex

name="$(scutil --get ComputerName 2>/dev/null || hostname)"
echo
echo "Workshop pack and agent installed."
echo "User:    $INSTALL_USER (uid $INSTALL_UID, home $INSTALL_HOME)"
echo "Pack:    $PACK"
echo "Starter: $PACK/Starter"
echo "Desktop: $DESKTOP_STARTER"
echo "Server:  ${SERVER%/}"
echo "Codex:   ${CODEX_STATUS:-not configured}"
echo
echo "Computer Name: $name"
echo "$DESKTOP_NOTE"
echo "Quit and reopen Xcode if it was open, then pick Codex in the Coding Assistant if it is not already selected."
echo "First Xcode launch may ask to install extra components; .command scripts may need Right-click → Open once."
echo "Confirm this Mac on ${SERVER%/}/admin under Workshop Macs."
echo "This installer does not reset the workshop."
echo

if [[ "${INTERACTIVE:-0}" == "1" ]] && command -v osascript >/dev/null 2>&1; then
  osascript <<APPLESCRIPT
display dialog "Pack and agent are installed on this Mac.

It will show up on the staff dashboard as:
${name}

${DESKTOP_NOTE}

Reset from /admin. This Mac must be on the network (Wi-Fi can be off during the session; a queued reset runs when it comes back)." buttons {"OK"} default button "OK"
APPLESCRIPT
fi
