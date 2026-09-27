#!/usr/bin/env bash
# tests/home.sh — Vikix's two promises about your home folder:
#
#   1. Stages are safe to re-run. 40-config and 60-login, run a second
#      time, change nothing: no new backups, no doubled blocks.
#   2. Undo works. snapshot → change your files → vikix undo puts them
#      back, and a second vikix undo brings the change back again.
#
# Both stages only touch $HOME, so they run for real, in a made-up home
# folder that starts with a StumpWM config and a .bashrc of its own.

set -euo pipefail
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
exit "$fail"
