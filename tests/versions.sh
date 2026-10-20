#!/usr/bin/env bash
# tests/versions.sh — vikix versions and vikix restore, for real, with restic
# and git in a made-up home: a settings file with two snapshots and three
# backups (the third the same as the second) lists as four versions, newest
# first, the two same backups folded into one row with from-to, and so does
# its folder, by everything under it; a restore
# brings one back beside the file as NAME (DATE).ext, twice as (DATE, 2),
# a folder as NAME (DATE)/; --replace puts the current one in the Trash
# first; a wrong ID, a file with no version, and a missing path each stop
# with a message; --json carries what Esploro reads.
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
mkdir -p "$HOME/.config/x" "$t/drive"
vv() { python3 "$here/bin/vikix-versions" "$@"; }
cfg="$HOME/.config/vikix"
file="$HOME/.config/x/settings.txt"
folder="$HOME/.config/x"

# --- the two histories ------------------------------------------------------------
bash "$here/bin/vikix-backup" setup "$t/drive" >/dev/null 2>&1 || { echo "FAIL: backup setup failed"; fail=1; }
repo="$t/drive/vikix-backup"
rb() { restic -q -r "$repo" --password-file "$cfg/backup-password" "$@"; }
yours="$HOME/.local/state/vikix/yours.git"
git init -q --bare "$yours"
yg() { git --git-dir="$yours" --work-tree="$HOME" -c user.name=Vikix -c user.email=vikix@localhost "$@"; }
snap() {   # snap "DATE" MESSAGE
  yg add -A -- "$HOME/.config/x"
  GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" yg commit -q -m "$2"
  yg rev-parse --short=7 HEAD
}
back() { rb backup --time "$1" "$HOME" >/dev/null 2>&1; rb snapshots --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[-1]["short_id"])'; }

printf 'v1\n' > "$file"
s1=$(snap "2026-09-29 09:12:00" "first")
touch -d "2026-09-29 09:12:00" "$file"
b1=$(back "2026-09-29 10:00:00")
printf 'v2 line\n' > "$file"
touch -d "2026-10-02 20:59:00" "$file"
s2=$(snap "2026-10-02 21:00:00" "second")
b2=$(back "2026-10-02 21:30:00")
b3=$(back "2026-10-04 08:00:00")   # nothing changed: folds into b2's row
printf 'v3 now\n' > "$file"

# --- the list ----------------------------------------------------------------------
out=$(vv "$file" 2>&1)
check "the head line doesn't count 4 versions: $(head -1 <<<"$out")" grep -q '^settings.txt: 4 versions, newest first' <<<"$out"
ids=$(grep -E '^  [0-9a-f]{7,8} ' <<<"$out" | awk '{print $1}' | tr '\n' ' ')
check "the order isn't newest first ($ids; want $b3 $s2 $b1 $s1)" test "$ids" = "$b3 $s2 $b1 $s1 "
check "the folded row doesn't carry the newest backup's ID" bash -c '! grep -q "^  $1 " <<<"$2"' _ "$b2" "$out"
check "the two same backups aren't one row, from-to" grep -qE "^  $b3 +Fri 2 Oct( 2026)? 21:30 to Sun 4 Oct( 2026)? 08:00 +backup +8 B" <<<"$out"
check "the second snapshot doesn't say what changed" grep -qE "^  $s2 .* snapshot +8 B +\+1 −1 lines" <<<"$out"
check "the first backup's row is wrong" grep -qE "^  $b1 +Tue 29 Sep( 2026)? 10:00 +backup +3 B" <<<"$out"
check "the first snapshot's row is wrong" grep -qE "^  $s1 +Tue 29 Sep( 2026)? 09:12 +snapshot +3 B" <<<"$out"
json=$(vv "$file" --json)
check "--json doesn't carry the four, with sources" test "$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["versions"]), " ".join(v["source"] for v in d["versions"]), d["exists"])' <<<"$json")" = "4 backup snapshot backup snapshot True"
check "--json's folded row lacks time_end" test "$(python3 -c 'import json,sys; v=json.load(sys.stdin)["versions"][0]; print(v["id"], v["time_end"] is not None, v["type"], v["size"])' <<<"$json")" = "$b3 True file 8"
# A folder: the backups folded by the folder's time, the snapshots by their tree.
fout=$(vv "$folder" 2>&1)
check "a folder's versions aren't 4 too (its file's), the same backups folded: $(head -1 <<<"$fout")" grep -q '^x: 4 versions' <<<"$fout"
check "a folder's size isn't its files' together" grep -qE "^  $s2 .* snapshot +8 B" <<<"$fout"
check "a folder's rows aren't of type dir" test "$(vv "$folder" --json | python3 -c 'import json,sys; print(set(v["type"] for v in json.load(sys.stdin)["versions"]))')" = "{'dir'}"
# The list is kept for a minute: a fourth backup doesn't show until --fresh.
b4=$(back "2026-10-05 08:00:00")
check "the kept list changed within the minute" test "$(vv "$file" | grep -c '^  [0-9a-f]')" = 4
check "--fresh doesn't read again" grep -q "^  $b4 " <<<"$(vv "$file" --fresh)"

# --- restore beside ------------------------------------------------------------------
vv restore "$file" "$b1" >/dev/null 2>&1 || { echo "FAIL: restore beside failed"; fail=1; }
beside="$HOME/.config/x/settings (Tue 29 Sep).txt"
check "the first backup didn't come back beside the file" test "$(cat "$beside" 2>/dev/null)" = "v1"
check "restore beside touched the file" test "$(cat "$file")" = "v3 now"
vv restore "$file" "${s1:0:5}" >/dev/null 2>&1 || { echo "FAIL: restore by the ID's start failed"; fail=1; }
check "the second beside isn't (DATE, 2)" test "$(cat "$HOME/.config/x/settings (Tue 29 Sep, 2).txt" 2>/dev/null)" = "v1"
vv restore "$folder" "$s2" >/dev/null 2>&1 || { echo "FAIL: restore of a folder failed"; fail=1; }
check "the folder didn't come back beside as NAME (DATE)/" test "$(cat "$HOME/.config/x (Fri 2 Oct)/settings.txt" 2>/dev/null)" = "v2 line"
vv restore "$folder" "$b1" >/dev/null 2>&1 || { echo "FAIL: restore of a folder from a backup failed"; fail=1; }
check "the folder from the backup didn't come back" test "$(cat "$HOME/.config/x (Tue 29 Sep)/settings.txt" 2>/dev/null)" = "v1"

# --- restore in place, through the Trash ----------------------------------------------
if command -v gio >/dev/null; then
  out=$(vv restore "$file" "$s2" --replace --json 2>&1) || { echo "FAIL: --replace failed: $out"; fail=1; }
  check "--replace didn't put the version in the file's place" test "$(cat "$file")" = "v2 line"
  check "--replace didn't say what went to the Trash" grep -q "\"trashed\": \"$file\"" <<<"$out"
  check "the current one isn't in the Trash" grep -qs 'v3 now' "$HOME/.local/share/Trash/files/settings.txt"
else
  echo "(gio isn't here: --replace left out)"
fi

# --- what stops ------------------------------------------------------------------------
if vv restore "$file" zzzz >/dev/null 2>&1; then echo "FAIL: a wrong ID restored something"; fail=1; fi
if vv restore "$HOME/never.txt" "$b1" >/dev/null 2>&1; then echo "FAIL: a file with no version restored something"; fail=1; fi
check "a file with no version doesn't say so" grep -q 'no version kept yet' <<<"$(vv "$HOME/never.txt" 2>&1)"
if vv >/dev/null 2>&1; then echo "FAIL: no path was accepted"; fail=1; fi
check "--help doesn't show the forms" grep -q 'vikix restore PATH ID' <<<"$(vv --help)"
mv "$t/drive" "$t/unplugged"
check "an unplugged drive isn't said, with the snapshots still listed" grep -q "drive isn't plugged in" <<<"$(vv "$file" --fresh 2>&1)"
check "the snapshots aren't listed without the drive" grep -q "^  $s2 " <<<"$(vv "$file" --fresh 2>&1)"

[ "$fail" = 0 ] && echo "versions: both histories in one list, newest first, the same backups folded; restore beside, twice, a folder, and in place through the Trash"
exit "$fail"
