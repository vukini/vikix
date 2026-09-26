#!/usr/bin/env bash
# 90-finish — settle the migrations, then say what to do next.
#
# On a fresh install there is no record of migrations yet. The install
# already contains every change the migrations/ folder describes, so
# they are all marked as applied, and `vikix update` then only ever runs
# migrations added after today.
#
# Re-running the installer on a machine that already has Vikix is
# different: a migration added since its last update has not happened
# there. Marking it as applied would skip it for good, so it is run.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

if [ -d "$VIKIX_STATE/migrations" ]; then
  say "Vikix was already installed here: running any new migrations"
  "$VIKIX_DIR/bin/vikix" migrate
else
  run mkdir -p "$VIKIX_STATE/migrations"
  for m in "$VIKIX_DIR"/migrations/*.sh; do
    [ -e "$m" ] || continue
    run touch "$VIKIX_STATE/migrations/$(basename "$m" .sh)"
  done
fi

if [ "${VIKIX_PHASE:-2}" = 1 ]; then
  cat <<EOF

  Part one is done: the desktop is installed.

  Next:
    1. Reboot:  sudo reboot
    2. Log in on tty1. The desktop starts by itself.
    3. Super+Return opens a terminal. In it, run part two:

         ~/vikix/install-2.sh

       Editors, languages, apps, sound, laptop hardware. It is the long
       part: it asks for your password once, then runs by itself, and a
       notification says when it has finished.

EOF
  exit 0
fi

cat <<EOF

  Vikix is installed.

  Next:
    1. Log out, then log back in on tty1 (Ctrl+Alt+F1).
       The desktop starts by itself.
    2. Super+Return opens a terminal. Super+F1 lists the Vikix keys.
    3. Your own StumpWM changes go in ~/.stumpwm.d/user.lisp.
    4. From Emacs: M-x slime-connect RET 127.0.0.1 RET 4004
       reaches the running window manager.
    5. Super+a opens Claude Code (it offers to install it the first
       time). Whatever it changes: vikix changes, then vikix undo.

  Later: 'vikix update' pulls changes and applies new migrations.

EOF
