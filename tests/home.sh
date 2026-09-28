#!/usr/bin/env bash
# tests/home.sh — Vikix's two promises about your home folder:
#
#   1. Stages are safe to re-run. 40-config and 60-login, run a second
#      time, change nothing: no new backups, no doubled blocks.
#   2. Undo works. snapshot → change your files → vikix undo puts them
#      back, and a second vikix undo brings the change back again.
#   3. API keys are never in the history: ~/.config/vikix/secrets stays out
#      even when yours.list names it, or a folder above it (a copy of the
#      checkout with such a yours.list proves it), and on a history that
#      began before the exclude existed.
#
# Both stages only touch $HOME, so they run for real, in a made-up home
# folder that starts with a StumpWM config and a .bashrc of its own.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state" XDG_STATE_HOME="$t/state-xdg"
mkdir -p "$HOME"
echo '(setf *old-config* t)' > "$HOME/.stumpwmrc"
echo 'alias mine="echo mine"' > "$HOME/.bashrc"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# What home looks like: every path, its type, link target and content.
picture() {
  (cd "$HOME" && find . -printf '%y %p -> %l\n' | sort
   find . -type f -exec sha1sum {} + | sort)
}

stages() {
  bash "$here/install/40-config.sh" >/dev/null
  bash "$here/install/60-login.sh" >/dev/null
}

# --- 1. safe to re-run ------------------------------------------------------
stages
check "the old .stumpwmrc didn't become user.lisp" grep -q old-config "$HOME/.stumpwm.d/user.lisp"
check ".stumpwmrc is still there, so StumpWM would skip Vikix" test ! -e "$HOME/.stumpwmrc"
check "the existing .bashrc lost its own line" grep -q 'alias mine' "$HOME/.bashrc"
first=$(picture)
stages
second=$(picture)
if [ "$first" != "$second" ]; then
  echo "FAIL: the second run changed home:"
  diff <(echo "$first") <(echo "$second") | sed 's/^/  /' | head -20
  fail=1
fi
check "a block appears twice in .bash_profile" \
  test "$(grep -c '^# >>> vikix startx >>>' "$HOME/.bash_profile")" = 1
[ "$fail" = 0 ] && echo "home: 40-config and 60-login change nothing when run again"

# --- 2. snapshot, change, undo, undo again ----------------------------------
vikix() { bash "$here/bin/vikix" "$@" >/dev/null; }
user="$HOME/.stumpwm.d/user.lisp"
before=$(cat "$user")
echo '(setf *changed* t)' >> "$user"
echo 'new = true' > "$HOME/.config/rofi/new.rasi"
changed=$(cat "$user")

vikix undo
check "undo left user.lisp changed" test "$(cat "$user")" = "$before"
check "undo left a new file in place" test ! -e "$HOME/.config/rofi/new.rasi"
vikix undo
check "a second undo didn't bring the change back" test "$(cat "$user")" = "$changed"
check "a second undo didn't bring the new file back" test -e "$HOME/.config/rofi/new.rasi"
check "files outside yours.list are in the snapshots" \
  test -z "$(git --git-dir="$VIKIX_STATE/yours.git" ls-files | grep -v -e '^\.stumpwm\.d/' -e '^\.config/' -e '^\.bash' -e '^\.Xresources')"
[ "$fail" = 0 ] && echo "home: undo puts your files back, and undo again brings the change back"

# --- 3. API keys never in the history -------------------------------------------
# Every file any snapshot ever recorded.
ever() { git --git-dir="$VIKIX_STATE/yours.git" log --all --name-only --format= | sort -u; }
no_secrets() { ! ever | grep -q '^\.config/vikix/secrets'; }
recorded() { ever | grep -qx "$1"; }
mkdir -p "$HOME/.config/vikix/secrets"
printf 'sk-ant-api03-HOMETESTKEY0123456789abcdef' > "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
vikix snapshot "with a key kept"
check "a kept key is in the history (the real yours.list)" no_secrets
# A yours.list that asks for it outright, and for the folder above it.
copy="$t/checkout"
mkdir -p "$copy"
(cd "$here" && tar --exclude=.git -cf - bin lib config install packages services.list VERSION) | tar -xf - -C "$copy"
printf '.config/vikix\n.config/vikix/secrets\n.config/vikix/secrets/ANTHROPIC_API_KEY\n' >> "$copy/config/yours.list"
out=$(bash "$copy/bin/vikix" snapshot "yours.list asks for the keys" 2>&1) ||
  { echo "FAIL: a snapshot failed when yours.list names the keys' folder:"; echo "$out" | tail -3 | sed 's/^/  /'; fail=1; }
check "the key is in the history when yours.list names its folder" no_secrets
check "the rest of .config/vikix, named by that yours.list, isn't in the history" recorded .config/vikix/keyboard
check "a yours.list naming the keys should get a warning: $out" grep -q 'API keys are never kept' <<<"$out"
# A history from before the exclude: its exclude file is rewritten at the next snapshot.
printf '*~\n' > "$VIKIX_STATE/yours.git/info/exclude"
bash "$copy/bin/vikix" snapshot "an old history" >/dev/null 2>&1
check "an old history's exclude didn't get the keys' folder" grep -qx '/.config/vikix/secrets/' "$VIKIX_STATE/yours.git/info/exclude"
check "the key reached an old history" no_secrets
[ "$fail" = 0 ] && echo "home: API keys stay out of the history, whatever yours.list says"
exit "$fail"
