#!/usr/bin/env bash
# tests/back.sh — vikix back: where you were, in a made-up home.
#
#   From the screen log: how long you were away (since when, or from when
#   to when once you're back), the window you left on and, when that was
#   no project (a terminal in ~), the project before it, with its next
#   step and last commit; the files Emacs has unsaved (a stand-in); your
#   last commands there (atuin's for the project's folder, else bash's
#   history); the inbox's last note. --card sends the short one as a
#   notification. Nothing kept yet is said.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME HISTFILE
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

export TZ=UTC NO_COLOR=1 HOME="$t/home"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.org
src="$HOME/src"; state="$HOME/.local/state/vikix"
mkdir -p "$src/alpha" "$state/day" "$HOME/.config/vikix/plugins/inbox" "$HOME/notes" "$t/bin"

git -C "$src/alpha" init -q -b main
printf '# Log: Alpha\n\n## 2026-10-03 · chapter four\n\nWrote it.\n\nNext: chapter five\n' > "$src/alpha/log.md"
git -C "$src/alpha" add log.md
GIT_AUTHOR_DATE="2026-10-04 09:00:00 +0000" GIT_COMMITTER_DATE="2026-10-04 09:00:00 +0000" \
  git -C "$src/alpha" commit -q -m "Chapter four, first draft"

at() { date -u -d "2026-10-04 $1" +%s; }
# On alpha in Emacs, then a terminal in ~, then away for 25 minutes (the
# away line is written five minutes in, saying so).
{
  printf '%s\tstart\n' "$(at 09:00)"
  printf '%s\tfocus\t2\t\temacs\t%s\n' "$(at 09:01)" "$src/alpha"
  printf '%s\tfocus\t3\t\tAlacritty\t%s\n' "$(at 09:40)" "$HOME"
  printf '%s\taway\t300\n' "$(at 09:50)"
} > "$state/day/screen-2026-10.log"

printf 'file = ~/notes/inbox.org\n' > "$HOME/.config/vikix/plugins/inbox/settings"
printf '#+title: Inbox\n\n* Old note\n* Ring the printer people\n:PROPERTIES:\n:CREATED:  [2026-10-04 Sun 09:30]\n:END:\n' > "$HOME/notes/inbox.org"
printf 'ls\nmake test\ngit status\n' > "$HOME/.bash_history"
# Emacs with one file not saved; atuin with the project's commands.
printf '#!/bin/sh\necho %s\n' "'(\"~/src/alpha/ch5.md\")'" > "$t/bin/emacsclient"
printf '#!/bin/sh\necho "atuin $*" >> %s/calls\nprintf "make book\\nvikix publish alpha\\n"\n' "$t" > "$t/bin/atuin"
printf '#!/bin/sh\necho "notify $*" >> %s/calls\n' "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/"*
: > "$t/calls"
back() { PATH="$t/bin:/usr/bin:/bin" VIKIX_NOW="$(at "$1")" python3 "$here/bin/vikix-back" "${@:2}" 2>&1; }

# Coming back at 10:10: still away, as far as the log goes.
out=$(back 10:10)
check "how long away, since when: $out" grep -qx "Away 25 min, since 09:45." <<<"$out"
check "the window you left on" grep -qx "You were in Alacritty, in ~." <<<"$out"
check "and the project before it, since a terminal in ~ is none" grep -qx "Before that, on alpha." <<<"$out"
check "its next step" grep -qx "Next: chapter five" <<<"$out"
check "its last commit" grep -q "^Last commit, 09:00: Chapter four, first draft$" <<<"$out"
check "what Emacs hasn't saved" grep -qx "Not saved in Emacs: ~/src/alpha/ch5.md" <<<"$out"
check "the commands in the project's folder, from atuin" grep -qx "  vikix publish alpha" <<<"$out"
check "asked for that folder" grep -q "^atuin search --cwd $src/alpha " "$t/calls"
check "the last note" grep -qx "Last note: Ring the printer people (2026-10-04 Sun 09:30)" <<<"$out"

# Back at 10:10, and asked at 11:00: the break as from-to.
printf '%s\tfocus\t2\t\temacs\t%s\n' "$(at 10:10)" "$src/alpha" >> "$state/day/screen-2026-10.log"
out=$(back 11:00)
check "asked later, the break from when to when: $out" grep -qx "Away 25 min, 09:45 to 10:10." <<<"$out"

# Without atuin: bash's history.
rm "$t/bin/atuin"
out=$(back 11:00)
check "without atuin, the end of bash's history" grep -qx "  git status" <<<"$out"

# The card: a notification, short.
: > "$t/calls"
back 11:00 --card >/dev/null
check "--card is a notification: $(cat "$t/calls")" grep -q "^notify -a Vikix Where was I? Away 25 min" "$t/calls"
check "a short one: the file's name, not its path" grep -q "Not saved in Emacs: ch5.md" "$t/calls"

# Nothing kept yet.
rm "$state/day/screen-2026-10.log" "$HOME/.bash_history" "$HOME/notes/inbox.org" "$t/bin/emacsclient"
out=$(back 11:00)
check "with nothing kept, that's said: $out" grep -q "^Nothing kept yet" <<<"$out"

[ "$fail" = 0 ] && echo "back: how long away and when, the window and the project before it with its next step and last commit, Emacs's unsaved files, the last commands there (atuin or bash), the last note, the card, and nothing kept said"
exit "$fail"
