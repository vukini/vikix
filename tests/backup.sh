#!/usr/bin/env bash
# tests/backup.sh — vikix backup, for real, with restic, in a made-up home:
# setup makes an encrypted store on a "drive" and a password only you can
# read; a backup leaves out what backup-exclude names; restore brings a
# file back beside the original, never over it; an unplugged drive, a
# wrong password and a missing setup each stop with a message; and the
# bar's reminder says the right thing (read from commands.lisp, run in sbcl);
# setup with no place takes the drive plugged in (vikix-drives on a made-up
# mounts file); the password card is written, shown and printed; doctor
# warns until a backup, a check and the card put away; the bar's menu backs up.
#
# Needs restic (tests/run.sh skips this test without it).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
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
check "the progress file should be gone after" test ! -e "$HOME/.local/state/vikix/backup-progress"
newest=$(ls -t "$HOME/.local/state/vikix/logs"/backup-*.log | head -1)
check "the log should be words, not restic's JSON: $(head -c 120 "$newest")" bash -c '! grep -q message_type "$1" && grep -q "done: .*files new" "$1"' _ "$newest"
vb now --notify >/dev/null 2>&1
check "--notify didn't say the backup was done" grep -q "Backup done" "$t/notes"

# --- the progress bar (lib/backup-progress.py on made-up restic lines) ---------------
# notify-send -p prints an id; the stand-in says 7, and writes down each call.
printf '#!/bin/sh\necho "$*" >> "%s/notes"\ncase " $* " in *" -p "*) echo 7 ;; esac\n' "$t" > "$t/bin/notify-send"
rm -f "$t/notes"
plog="$t/progress.log"; pfile="$t/progress"
pb() { python3 "$here/lib/backup-progress.py" --log "$plog" --progress "$pfile" --notify --bar; }
out=$(printf '%s\n' \
  '{"message_type":"verbose_status","action":"scan_finished","item":"","total_files":3}' \
  '{"message_type":"status","percent_done":0.42,"total_files":5000,"files_done":1234,"total_bytes":29100000000,"bytes_done":12300000000,"seconds_remaining":250}' \
  '{"message_type":"error","error":{"message":"permission denied"},"during":"archival","item":"/home/me/locked"}' \
  'plain words from restic' \
  '{"message_type":"summary","files_new":12,"files_changed":3,"files_unmodified":4000,"data_added":1200000000,"total_duration":185.2,"snapshot_id":"abcdef1234567890"}' \
  | { pb 2>"$t/progress.err"; echo "rc=$?"; echo "file after: $(cat "$pfile" 2>/dev/null || echo gone)"; })
check "the filter should exit 0 and remove the progress file: $out" bash -c 'grep -q "rc=0" <<<"$1" && grep -q "file after: gone" <<<"$1"' _ "$out"
check "the bar should show the percent and the amounts: $(cat "$t/progress.err")" grep -q '\[########............\]  42%  12.3 GB of 29.1 GB, 1234/5000 files, 4 min left' "$t/progress.err"
check "the error should be said as it comes" grep -q 'error: permission denied (/home/me/locked)' "$t/progress.err"
check "restic's plain words should be said too" grep -q 'error: plain words from restic' "$t/progress.err"
check "the summary should be in words on stdout: $out" grep -q 'backup done: 12 files new, 3 changed, 4000 unchanged, 1.2 GB added, took 3 min; backup abcdef12' <<<"$out"
check "the log should have the progress, the error and the summary: $(cat "$plog")" bash -c 'grep -q " 42%  12.3 GB" "$1" && grep -q "error: permission denied" "$1" && grep -q "done: 12 files new" "$1" && ! grep -q message_type "$1"' _ "$plog"
check "the notification should carry dunst's bar and be replaced, not added: $(cat "$t/notes")" bash -c 'grep -q -- "-h int:value:42 -p Backup 42% 12.3 GB of 29.1 GB" "$1" && grep -q -- "-h int:value:100 -r 7 Backup done 12 files new" "$1"' _ "$t/notes"
# The bar's file while it runs: PERCENT and the time, within a second.
printf '{"message_type":"status","percent_done":0.5,"total_bytes":10,"bytes_done":5}\n' |
  python3 -c '
import subprocess, sys, time
p = subprocess.Popen([sys.executable, sys.argv[1], "--progress", sys.argv[2]], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
p.stdin.write(sys.stdin.buffer.read()); p.stdin.flush()
time.sleep(0.5)
words = open(sys.argv[2]).read().split()
ok = words[0] == "50" and abs(int(words[1]) - time.time()) < 5
p.stdin.close(); p.wait()
sys.exit(0 if ok else 1)' "$here/lib/backup-progress.py" "$pfile" || { echo "FAIL: the progress file should say 50 and the time while the backup runs"; fail=1; }

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

# --- setup with no place: the drive plugged in --------------------------------
# vikix-drives lists the mounts under VIKIX_MEDIA from VIKIX_MOUNTS.
mkdir -p "$t/media/STICK" "$t/media/OTHER"
export VIKIX_MEDIA="$t/media" VIKIX_MOUNTS="$t/mounts"
: > "$t/mounts"
out=$(vb setup 2>&1 </dev/null || true)
check "no drive: setup should say to plug one in: $out" grep -q "no USB drive is plugged in" <<<"$out"
printf '/dev/sdb1 %s/media/STICK vfat rw 0 0\n/dev/sdc1 %s/media/OTHER vfat rw 0 0\n' "$t" "$t" > "$t/mounts"
out=$(vb setup 2>&1 </dev/null || true)
check "two drives, no terminal: setup should name them and stop: $out" bash -c 'grep -q "several drives" <<<"$1" && grep -q "STICK" <<<"$1" && grep -q "OTHER" <<<"$1"' _ "$out"
check "and set nothing up" bash -c '! grep -q "media/" "$1" 2>/dev/null' _ "$cfg/backup"
printf '/dev/sdb1 %s/media/STICK vfat rw 0 0\n' "$t" > "$t/mounts"
out=$(vb setup 2>&1)
check "one drive: setup should take it: $out" grep -q "the drive plugged in: $t/media/STICK" <<<"$out"
check "and make the store on it" test -f "$t/media/STICK/vikix-backup/config"
check "and point the settings at it" grep -qx "REPO=$t/media/STICK/vikix-backup" "$cfg/backup"

# --- the password card ---------------------------------------------------------
out=$(VIKIX_BACKUP_CARD_TEXT=1 vb card "$t/card" 2>&1)
check "the card should show the password: $out" grep -qF "$pw" <<<"$out"
check "and where the backups go" grep -q "Backups go to: $t/media/STICK/vikix-backup" <<<"$out"
check "the card should be written where asked" test -f "$t/card.txt"
check "for you alone" test "$(stat -c %a "$t/card.txt")" = 600
if command -v typst >/dev/null; then
  vb card "$t/card2" >/dev/null 2>&1
  check "with typst the card should be a PDF" bash -c 'head -c 4 "$1" | grep -q "%PDF"' _ "$t/card2.pdf"
fi
printf '#!/bin/sh\necho "no system default destination"\n' > "$t/bin/lpstat"; chmod +x "$t/bin/lpstat"
out=$(VIKIX_BACKUP_CARD_TEXT=1 vb card --print 2>&1 || true)
check "--print without a printer should say so, and where the card is: $out" bash -c 'grep -q "no printer is set up" <<<"$1" && grep -q "vikix-backup-card.txt" <<<"$1"' _ "$out"
printf '#!/bin/sh\necho "system default destination: office"\n' > "$t/bin/lpstat"
printf '#!/bin/sh\necho "$*" > "%s/printed"\n' "$t" > "$t/bin/lp"; chmod +x "$t/bin/lpstat" "$t/bin/lp"
out=$(VIKIX_BACKUP_CARD_TEXT=1 vb card --print 2>&1)
check "--print should send the card to lp: $(cat "$t/printed" 2>/dev/null)" grep -q "vikix-backup-card.txt" "$t/printed"

# --- doctor ----------------------------------------------------------------------
out=$(vb doctor 2>&1 || true); rc=0; vb doctor >/dev/null 2>&1 || rc=$?
check "doctor before a backup should warn three ways and fail: $out" bash -c 'grep -q "no backup yet" <<<"$1" && grep -q "never read back" <<<"$1" && grep -q "card isn.t put away" <<<"$1"' _ "$out"
check "and exit 1" test "$rc" = 1
vb card --kept >/dev/null
check "--kept should be written down" grep -qx "CARD=kept" "$cfg/backup"
vb now >/dev/null 2>&1; vb check >/dev/null 2>&1
check "check should note its time" test -s "$HOME/.local/state/vikix/backup-check"
out=$(vb doctor 2>&1); rc=0; vb doctor >/dev/null 2>&1 || rc=$?
check "doctor after all three should be content: $out" bash -c 'grep -q "last backup was today" <<<"$1" && grep -q "checked today" <<<"$1" && grep -q "card is kept" <<<"$1" && ! grep -q "^!!" <<<"$1"' _ "$out"
check "and exit 0" test "$rc" = 0
out=$(vb setup "$t/media/STICK" 2>&1)
check "setup again should keep the card noted" grep -qx "CARD=kept" "$cfg/backup"
mv "$t/media/STICK" "$t/media/GONE"
out=$(vb doctor 2>&1 || true)
check "doctor with the drive unplugged should say so: $out" grep -q "drive isn.t plugged in" <<<"$out"
mv "$t/media/GONE" "$t/media/STICK"

# --- the bar's menu ------------------------------------------------------------
# rofi is a stand-in that picks the line $t/rofi names.
printf '#!/bin/sh\ncat > /dev/null; cat "%s/rofi"\n' "$t" > "$t/bin/rofi"; chmod +x "$t/bin/rofi"
rm -f "$t/notes"; echo "Back up now" > "$t/rofi"
vb menu >/dev/null 2>&1
check "the menu's Back up now should back up and say so: $(cat "$t/notes" 2>/dev/null)" grep -q "Backup done" "$t/notes"

# --- the bar's words (vikix-backup-text, from commands.lisp) ---------------------
if command -v sbcl >/dev/null; then
  fn=$(awk '/^\(defun vikix-backup-text/,/^$/' "$here/config/stumpwm/vikix/commands.lisp")
  pfn=$(awk '/^\(defun vikix-backup-progress-text/,/^$/' "$here/config/stumpwm/vikix/commands.lisp")
  words=$(sbcl --noinform --no-sysinit --no-userinit --non-interactive \
    --eval "$fn" --eval "$pfn" \
    --eval '(let ((now 1800000000))
              (format t "~s ~s ~s ~s ~s ~s ~s ~s~%"
                (vikix-backup-text nil 7 now) (vikix-backup-text 0 7 now)
                (vikix-backup-text (- now (* 3 86400)) 7 now)
                (vikix-backup-text (- now (* 9 86400)) 7 now)
                (vikix-backup-text (- now (* 7 86400)) 7 now)
                (vikix-backup-progress-text 42 (- now 5) now)
                (vikix-backup-progress-text 42 (- now 120) now)
                (vikix-backup-progress-text nil nil now)))' 2>&1 | tail -1)
  check "the bar's reminder words are wrong: $words" \
    test "$words" = '"" "backup" "" "backup 9d" "backup 7d" "backup 42%" "" ""'
fi

[ "$fail" = 0 ] && echo "backup: setup (a place, or the drive plugged in), backup without the left-out folders, restore beside the original, the password card, doctor's lines, the bar's menu and its reminder"
exit "$fail"
