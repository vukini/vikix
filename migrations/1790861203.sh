#!/usr/bin/env bash
# Why: from 0.71.17 the wallpaper cycles by default: a new picture every 30
# minutes from Vid's collection and your own wallpaper folders, unless you
# chose a picture, the theme's, or your own tool. vikix-session starts the
# watcher that changes it at login; this starts it now, in the session
# `vikix update` runs in. A picture you chose, or off, stays as it is.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

conf=${XDG_CONFIG_HOME:-$HOME/.config}/vikix
if [ -e "$conf/wallpaper-off" ]; then
  say "you set the wallpaper with your own tool; Vikix leaves it alone"
elif [ -e "$conf/wallpaper" ]; then
  say "you chose a wallpaper; it stays. To cycle instead: vikix-wallpaper cycle"
else
  say "the wallpaper now cycles (Super+m, Wallpaper: Theme puts the theme's back)"
fi
if [ -z "${DISPLAY:-}" ]; then
  say "not in the desktop; the wallpaper watcher starts at the next login"
else
  run setsid -f "$VIKIX_DIR/bin/vikix-wallpaper" --watch >/dev/null 2>&1 </dev/null
  [ -e "$conf/wallpaper" ] || [ -e "$conf/wallpaper-off" ] || run "$VIKIX_DIR/bin/vikix-wallpaper" || true
fi
