#!/usr/bin/env bash
# Why: the first migration, kept as the worked example of the pattern.
# Machines installed before `xdotool` joined packages/desktop.list don't
# have it, and `vikix update` would add it anyway through 10-packages —
# so this one only shows the shape: check first, then change.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

if pkg_installed xdotool; then
  say "xdotool already installed"
else
  run sudo xbps-install -y xdotool
fi
