#!/usr/bin/env bash
# Why: from 0.33.0 the desktop runs udiskie, so a USB drive mounts when
# it's plugged in. vikix-session starts it at login; this starts it now,
# in the session `vikix update` runs in, so it works before the next login.
# Nothing to do outside a desktop session, or if it's already running.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

if [ -z "${DISPLAY:-}" ]; then
  say "not in the desktop; udiskie starts at the next login"
elif pgrep -x udiskie >/dev/null 2>&1; then
  say "udiskie is already running"
elif ! command -v udiskie >/dev/null 2>&1; then
  say "udiskie isn't installed yet; it comes with part two (apps.list)"
else
  say "starting udiskie: USB drives now mount when plugged in"
  run setsid -f "$VIKIX_DIR/bin/vikix-drives" start >/dev/null 2>&1 </dev/null
fi
