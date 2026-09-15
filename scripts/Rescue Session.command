#!/bin/bash
# Mid-session rescue: rewind the Xcode project to this pair's seed, not a
# blank grey shell and not a new look. Double-click, or run with --yes.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/Reset Workshop.command" --rescue "$@"
