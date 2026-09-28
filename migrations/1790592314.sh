#!/usr/bin/env bash
# Why: from 0.48.0 StumpWM opens the welcome (vikix welcome) at the first
# login on a new desktop: add software, the keys, a theme, the keyboard,
# the guide. A desktop that's been in use already knows its way round, so
# mark the welcome as shown there; Super+m, Welcome still opens it. This
# runs before vikix update reloads StumpWM, which is when it would look.
# Safe to run twice: it only makes the file when it isn't there.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

state="$VIKIX_STATE/welcome"
if [ -e "$state" ]; then
  say "the welcome was already shown here"
else
  mkdir -p "$(dirname "$state")"
  : > "$state"
  say "the welcome won't open by itself here (Super+m, Welcome opens it)"
fi
