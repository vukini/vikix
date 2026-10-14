#!/usr/bin/env bash
# Why: from 2026-10-14 every task of the office is a record of its own
# (~/.local/state/vikix/office/tasks/ID.json, lib/tasks.py: TODO 115, phase 1
# of plans/DESIGN-office-tasks.md), made by every way work starts. The desks
# already here keep their records as they are, but their tasks and the
# workers in their histories have no record yet: `vikix agents tasks adopt`
# makes one for each, with what the desk's record knew and nothing more
# (the launch order, for one, is unknown and shown so). And the office's
# settings file, ~/.config/vikix/office, gets the board's settings as
# comments with their defaults (at_once, auto, quiet, delegate,
# delegate_max: read by the queue and the attention list of the later
# phases), so a user finds them before they are needed; a line already
# there, such as mode=, stays.
# office-tasks-adopt
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

if [ "${DRY_RUN:-0}" = 1 ]; then
  printf '   would make task records for the desks from before (vikix agents tasks adopt)\n'
else
  python3 "$VIKIX_DIR/bin/vikix-agents" tasks adopt || warn "the desks from before weren't adopted (vikix agents tasks adopt runs it again)"
fi

office="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/office"
if ! grep -q '^#* *at_once=' "$office" 2>/dev/null; then
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '   would write the task board'"'"'s settings as comments into %s\n' "$office"
  else
    mkdir -p "$(dirname "$office")"
    cat >> "$office" <<'SETTINGS'
# The task board (vikix agents tasks, the Office; plans/DESIGN-office-tasks.md).
# Each line below is the default: uncomment one to change it. The queue and
# the attention list that read them come with the design's later phases.
# at_once=2        workers running at once, at most, when the queue starts them
# auto=off         on: the queue starts the next eligible task by itself, within at_once
# quiet=20         minutes without a sign from a worker before its task is said uncertain
# delegate=ask     ask: every task an agent proposes waits for your approval; allow: under a parent that may delegate
# delegate_max=3   tasks agents may delegate in a day, over every parent
SETTINGS
    say "office: the task board's settings written as comments into $office"
  fi
fi
