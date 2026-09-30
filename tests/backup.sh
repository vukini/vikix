#!/usr/bin/env bash
# tests/backup.sh — vikix backup, for real, with restic, in a made-up home:
# setup makes an encrypted store on a "drive" and a password only you can
# read; a backup leaves out what backup-exclude names; restore brings a
# file back beside the original, never over it; an unplugged drive, a
# wrong password and a missing setup each stop with a message; and the
# bar's reminder says the right thing (read from commands.lisp, run in sbcl).
#
# Needs restic (tests/run.sh skips this test without it).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
command -v restic >/dev/null || { echo "FAIL no restic (xbps-install restic, or apt install restic)"; exit 1; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

export HOME="$t/home"
mkdir -p "$HOME/Documents" "$HOME/.cache/thumbs" "$HOME/code/app/node_modules/x" \
         "$HOME/dev/lua/docs" "$t/bin" "$t/drive"
echo "my notes" > "$HOME/Documents/notes.txt"
echo "cached"   > "$HOME/.cache/thumbs/big"
echo "module"   > "$HOME/code/app/node_modules/x/index.js"
echo "app"      > "$HOME/code/app/main.js"
echo "manual"   > "$HOME/dev/lua/docs/manual.html"
# Notifications are written down, not shown.
printf '#!/bin/sh\necho "$*" >> "%s/notes"\n' "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/notify-send"
export PATH="$t/bin:$PATH"

vb() { bash "$here/bin/vikix-backup" "$@"; }
cfg="$HOME/.config/vikix"
bar="$HOME/.local/state/vikix/backup"

# --- before setup -------------------------------------------------------------
check "status before setup doesn't say so" sh -c "bash '$here/bin/vikix-backup' status | grep -q 'not set up'"
if vb now >/dev/null 2>&1; then echo "FAIL: a backup ran with nothing set up"; fail=1; fi
if vb setup "$t/nowhere" >/dev/null 2>&1; then echo "FAIL: setup took a drive that isn't there"; fail=1; fi

# --- setup ----------------------------------------------------------------------
out=$(vb setup "$t/drive" 2>&1)
repo="$t/drive/vikix-backup"
check "setup made no restic store on the drive" test -f "$repo/config"
check "the password file isn't for you alone" test "$(stat -c %a "$cfg/backup-password")" = 600
check "setup didn't show the password to write down" grep -qF "$(cat "$cfg/backup-password")" <<<"$out"
check "the settings don't name the store" grep -qx "REPO=$repo" "$cfg/backup"
check "the exclude list wasn't given to you" test -f "$cfg/backup-exclude"
check "the bar isn't told 'none yet'" test "$(cat "$bar")" = "0 7"
pw=$(cat "$cfg/backup-password")

# --- a backup -----------------------------------------------------------------
vb now >/dev/null 2>&1 || { echo "FAIL: the backup failed"; fail=1; }
files=$(restic -r "$repo" --password-file "$cfg/backup-password" ls latest 2>/dev/null)
check "your notes aren't in the backup" grep -q "/Documents/notes.txt$" <<<"$files"
check "your code isn't in the backup" grep -q "/code/app/main.js$" <<<"$files"
lacks() { ! grep -q "$1" <<<"$files"; }
check "the cache folder went into the backup" lacks '/.cache/'
check "node_modules went into the backup" lacks node_modules
check "the offline docs went into the backup" lacks '/dev/lua/docs'
last=$(cut -d' ' -f1 "$bar")
check "the bar wasn't told when the backup ran" test "$(( $(date +%s) - last ))" -lt 300
# From a terminal it prints; notifications are for the menu's --notify.
check "a backup from the terminal sent notifications" test ! -e "$t/notes"
vb now --notify >/dev/null 2>&1
check "--notify didn't say the backup was done" grep -q "Backup done" "$t/notes"

# --- restore ------------------------------------------------------------------
echo "changed" > "$HOME/Documents/notes.txt"
vb restore "$HOME/Documents/notes.txt" >/dev/null 2>&1 || { echo "FAIL: restore failed"; fail=1; }
back=$(find "$HOME/Restored" -path '*/Documents/notes.txt' 2>/dev/null | head -1 || true)
check "the restored file isn't in ~/Restored" test -n "$back"
check "the restored file isn't the backed-up one" test "$(cat "$back" 2>/dev/null)" = "my notes"
check "restore overwrote the original" test "$(cat "$HOME/Documents/notes.txt")" = "changed"
if vb restore "$HOME/never-there.txt" >/dev/null 2>&1; then echo "FAIL: restoring a missing file claimed success"; fail=1; fi

# --- the drive unplugged, setup again, a wrong password ------------------------
mv "$t/drive" "$t/unplugged"
if vb now >/dev/null 2>&1; then echo "FAIL: a backup ran with the drive unplugged"; fail=1; fi
mv "$t/unplugged" "$t/drive"
out=$(vb setup "$t/drive" 2>&1)
check "setup again didn't reuse the store" grep -q "using the backups already" <<<"$out"
check "setup again changed the password" test "$(cat "$cfg/backup-password")" = "$pw"
check "setup again showed the password again" bash -c '! grep -qF "$1" <<<"$2"' _ "$pw" "$out"
echo "not the password" > "$cfg/backup-password"
if vb setup "$t/drive" >/dev/null 2>&1; then echo "FAIL: setup accepted a store with another password"; fail=1; fi
echo "$pw" > "$cfg/backup-password"

# --- off -------------------------------------------------------------------------
vb off >/dev/null
check "off left the reminder on" test ! -e "$bar"
check "off removed the backups" test -f "$repo/config"

# --- the bar's words (vikix-backup-text, from commands.lisp) ---------------------
if command -v sbcl >/dev/null; then
  fn=$(awk '/^\(defun vikix-backup-text/,/^$/' "$here/config/stumpwm/vikix/commands.lisp")
  words=$(sbcl --noinform --no-sysinit --no-userinit --non-interactive \
    --eval "$fn" \
    --eval '(let ((now 1800000000))
              (format t "~s ~s ~s ~s ~s~%"
                (vikix-backup-text nil 7 now) (vikix-backup-text 0 7 now)
                (vikix-backup-text (- now (* 3 86400)) 7 now)
                (vikix-backup-text (- now (* 9 86400)) 7 now)
                (vikix-backup-text (- now (* 7 86400)) 7 now)))' 2>&1 | tail -1)
  check "the bar's reminder words are wrong: $words" \
    test "$words" = '"" "backup" "" "backup 9d" "backup 7d"'
fi

[ "$fail" = 0 ] && echo "backup: setup, backup without the left-out folders, restore beside the original, and the bar's reminder"
exit "$fail"
