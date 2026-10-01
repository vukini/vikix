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

# What to say depends on what came with the base.
added=${VIKIX_ADDED:-}
if [ -n "$added" ]; then
  more="  Added: $added. vikix features shows the rest."
else
  more="  The base is in. Next, add what you want, from a terminal:

         vikix features          what there is
         vikix add essentials    Emacs, and C, Python and Lisp
         vikix add everything    every editor and language, LibreOffice,
                                 printing (a few GB)"
fi

cat <<EOF

  Vikix is installed.

  Next:
    1. Reboot:  sudo reboot   (or, if Vikix was already running here,
       log out and back in on tty1)
    2. Log in on tty1. The desktop starts by itself.
    3. Super+Return opens a terminal. Super+/ shows the Vikix keys,
       and Super+m is the menu for everything else.
    4. Super+a opens Claude Code, the AI agent (it offers to install it
       the first time). Whatever it changes: vikix changes, then vikix undo.

$more

  Later: 'vikix update' keeps all of it current.

EOF
