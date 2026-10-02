#!/usr/bin/env bash
# Why: from 0.71.40 the meeting web apps (teams, meet, zoom) start with the
# camera and microphone allowed for their own site: a web app's window has
# no address bar, so Chromium's question is easily missed, and the
# meeting's device settings stay greyed out. One made before has no mark
# for that; this gives it one (vikix webapp media NAME off takes it away).
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

list="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/webapps"
profiles="${XDG_DATA_HOME:-$HOME/.local/share}/vikix/webapps"
[ -f "$list" ] || { say "no web apps"; exit 0; }
while read -r name url _; do
  case $name in teams|meet|zoom) ;; *) continue ;; esac
  [ -n "$url" ] || continue
  if [ -e "$profiles/$name/.vikix-media" ]; then
    say "$name: the camera and microphone already allowed"
  else
    run mkdir -p "$profiles/$name"
    run touch "$profiles/$name/.vikix-media"
    say "$name: the camera and microphone allowed from its next start"
  fi
done < <(grep -v '^[[:space:]]*#' "$list")
