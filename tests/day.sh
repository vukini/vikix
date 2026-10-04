#!/usr/bin/env bash
# tests/day.sh — `vikix day` (bin/vikix-day) and what the desktop writes
# down for it (day.lisp).
#
# First in a made-up home, no network, no desktop:
#   - the screen's log added up: a project by its folder, by a git worktree
#     of it and by the workspace opened for it; the rest by program; time
#     away (the away line cuts back to when the idleness began), a power
#     cut (no line for too long), a restart, the window still in front now,
#     and a night that began the day before
#   - commits in a repo of many projects go to the project whose folder
#     they changed (a commit across two to both; the rest to the repo's own)
#   - the day: each project's time, log entries, commits and next step;
#     Esploro's changes (one undone), agents' sessions with what changed in
#     the settings after each, Vikix's updates, other snapshots, the rules
#     that ran, documents opened (each once), the plugins' records
#   - the file: ~/journal/DATE.org, 600 in a 700 folder, written again each
#     run with what's under Notes kept; --no-file and --for write none;
#     folder= in ~/.config/vikix/day; path; a day that hasn't happened
#   - --week and --for NAME
#   - day log: without a terminal it prints the drafts and writes nothing;
#     in one, a yes writes the entry (the day's date, newest first kept),
#     the next step and the percentage; a project with its entry isn't asked
#   - vikix day reaches it; vikix docs open notes the document
#
# Then, in a real StumpWM on a hidden screen (tests/lib/wm.sh; skipped
# without Xvfb, xdotool, alacritty or Vikix's StumpWM): the ticker writes
# start and what's in front (workspace, project, class, folder; never the
# title), once; away once, then the window again; a beat five minutes on;
# a rule that ran; nothing with *vikix-day-on* nil; the file is 600; and
# vikix day reads what it wrote.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset CLAUDECODE XDG_CONFIG_HOME XDG_DATA_HOME VIKIX_RECORDS_DB   # CLAUDECODE: run from Claude Code, a log entry would be the agent's
here=$(cd "$(dirname "$0")/.." && pwd)
t0=$(mktemp -d)
trap 'rm -rf "$t0"' EXIT
fail=0
n=0
expect() { n=$((n + 1)); if "${@:2}"; then :; else echo "FAIL: $1"; fail=1; fi; }
has() { grep -qF -- "$1" <<<"$2"; }
hasnt() { ! grep -qF -- "$1" <<<"$2"; }

export TZ=UTC NO_COLOR=1
home="$t0/home"
src="$home/src"
state="$home/.local/state/vikix"
mkdir -p "$src" "$state/day" "$home/.config/vikix" "$t0/bin"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.org

at() { date -u -d "$1" +%s; }
commit() {   # commit REPO "DATE TIME" SUBJECT
  GIT_AUTHOR_DATE="$2 +0000" GIT_COMMITTER_DATE="$2 +0000" git -C "$1" commit -q --allow-empty -m "$3"
}

# alpha: a repo with a Status and an entry from the day before; a worktree of it.
mkdir -p "$src/alpha"
git -C "$src/alpha" init -q -b main
cat > "$src/alpha/log.md" <<'EOF'
# Log: Alpha

**Status** (the book), as of 2026-09-30: 40% complete.
- Next: chapter five

## 2026-10-01 · chapter four

Wrote chapter four.

Next: chapter five
EOF
git -C "$src/alpha" add log.md
commit "$src/alpha" "2026-10-01 09:00:00" "First thing"
commit "$src/alpha" "2026-10-02 10:00:00" "Second thing"
commit "$src/alpha" "2026-10-02 11:00:00" "Third thing."
git -C "$src/alpha" worktree add -q "$src/alpha-wt" -b wt
mkdir -p "$src/alpha-wt/sub"
# beta: no repo, an entry on the day.
mkdir -p "$src/beta"
printf '# Log: Beta\n\n## 2026-10-02 · drawings (Vid)\n\nDrew the cover.\n\nNext: the spine\n' > "$src/beta/log.md"
# gamma: commits the day before, an entry on the day only.
mkdir -p "$src/gamma"
git -C "$src/gamma" init -q -b main
printf '# Log: Gamma\n\n## 2026-10-02 · later\n\nLater work.\n' > "$src/gamma/log.md"
git -C "$src/gamma" add log.md
commit "$src/gamma" "2026-10-01 15:00:00" "Earlier work"

# series: one repo, a project at its top and two inside; commits two days before.
mkdir -p "$src/series/one" "$src/series/two"
git -C "$src/series" init -q -b main
printf '# Log: Series\n' > "$src/series/LOG.md"
printf '# Log: One\n' > "$src/series/one/log.md"
printf '# Log: Two\n' > "$src/series/two/log.md"
filed() {   # filed "DATE TIME" SUBJECT FILE...: a commit that changes those files
  local f
  for f in "${@:3}"; do echo "$2" >> "$src/series/$f"; done
  git -C "$src/series" add -A
  commit "$src/series" "$1" "$2"
}
filed "2026-09-29 09:00:00" "The logs" README
filed "2026-09-30 09:00:00" "One only" "one/a b.txt"
filed "2026-09-30 10:00:00" "Both of them" one/c.txt two/c.txt
filed "2026-09-30 11:00:00" "The series' own" shared.txt

# The screen's log: span START END FIELDS writes the focus line and a beat every five minutes.
log="$state/day/screen-2026-10.log"
line() { printf '%s\t%s\n' "$(at "$1")" "$2" >> "$log"; }
span() {
  local a b
  a=$(at "$1"); b=$(at "$2")
  printf '%s\tfocus\t%s\n' "$a" "$3" >> "$log"
  for ((s = a + 300; s < b; s += 300)); do printf '%s\tbeat\n' "$s" >> "$log"; done
}
tab=$'\t'
span "2026-10-01 23:50" "2026-10-02 00:10" "1${tab}${tab}Firefox${tab}$home"       # over midnight
line "2026-10-02 00:10" "away${tab}0"
line "2026-10-02 08:00" "start"
span "2026-10-02 08:00" "2026-10-02 09:00" "1${tab}${tab}Alacritty${tab}$src/alpha"
line "2026-10-02 09:00" "rule${tab}nmtui"
line "2026-10-02 09:00" "rule${tab}at 09:00"
line "2026-10-02 09:01" "rule${tab}nmtui"
span "2026-10-02 09:00" "2026-10-02 09:30" "1${tab}${tab}Alacritty${tab}$src/alpha-wt/sub"   # a worktree
span "2026-10-02 09:30" "2026-10-02 10:00" "2${tab}${tab}Firefox${tab}$home"
span "2026-10-02 10:00" "2026-10-02 10:30" "3${tab}beta${tab}Emacs${tab}"            # the workspace's project
line "2026-10-02 10:30" "away${tab}600"                                           # idle since 10:20
span "2026-10-02 11:00" "2026-10-02 11:15" "1${tab}${tab}Alacritty${tab}$src/alpha"   # then the power went: last line 11:10
line "2026-10-02 13:00" "start"
span "2026-10-02 13:00" "2026-10-02 13:05" "2${tab}${tab}Firefox${tab}$home"
span "2026-10-02 13:05" "2026-10-02 18:00" "1${tab}${tab}Alacritty${tab}$src/alpha"   # still in front now

# Esploro's changes, as it prints them.
cat > "$t0/bin/esploro" <<'EOF'
#!/bin/sh
[ "$1" = changes ] || exit 1
cat <<'OUT'
(("f2" "2026-10-02T09:20:00" "trashed \"old (1).txt\"" T NIL "/h") ("f1" "2026-10-02T09:15:00" "moved 3 files into ~/Work" NIL ("move a to b") "/h")
 ("f0" "2026-10-01T09:00:00" "the day before's" NIL NIL "/h"))
OUT
EOF
chmod +x "$t0/bin/esploro"

# The snapshot history of the settings.
yours() { git --git-dir="$state/yours.git" --work-tree="$home" "$@"; }
snap() { GIT_AUTHOR_DATE="$1 +0000" GIT_COMMITTER_DATE="$1 +0000" yours commit -q --allow-empty -m "$2"; }
yours init -q -b main
mkdir -p "$home/.stumpwm.d"
echo ';; yours' > "$home/.stumpwm.d/user.lisp"
yours add -f .stumpwm.d/user.lisp
snap "2026-10-02 08:05:00" "before an agent session (claude)"
echo '(one)' >> "$home/.stumpwm.d/user.lisp"; yours add -f .stumpwm.d/user.lisp
snap "2026-10-02 08:30:00" "after installing or updating Vikix 0.9.1"
snap "2026-10-02 09:00:00" "after installing or updating Vikix 0.9.2"
snap "2026-10-02 09:30:00" "before: a rule for Firefox"
snap "2026-10-02 17:00:00" "before an agent session (codex)"
echo '(two)' >> "$home/.stumpwm.d/user.lisp"   # changed since, no snapshot yet

# Documents opened, and the plugins' records.
printf '%s\tman:ls\tls(1) — list directory contents\n%s\tman:ls\tls(1) — list directory contents\n%s\tvikix:rules\tRules\n%s\tman:cp\tthe day before\n' \
  "$(at '2026-10-02 11:00')" "$(at '2026-10-02 11:05')" "$(at '2026-10-02 11:10')" "$(at '2026-10-01 11:10')" > "$state/day/docs.log"
vd() { HOME=$home PATH="$t0/bin:$PATH" VIKIX_TODAY=2026-10-02 VIKIX_NOW=$(at "2026-10-02 18:00:30") python3 "$here/bin/vikix-day" "$@" 2>&1; }
rec() { HOME=$home python3 "$here/bin/vikix-records" add >/dev/null; }
echo "{\"plugin\": \"flights\", \"kind\": \"search\", \"key\": \"a\", \"title\": \"DXB LHR 12 Nov\", \"at\": $(at '2026-10-02 12:00')}" | rec
for i in 1 2 3 4; do
  echo "{\"plugin\": \"ai-usage\", \"kind\": \"usage\", \"key\": \"u$i\", \"title\": \"plan $i\", \"at\": $(at "2026-10-02 12:0$i")}" | rec
done
echo "{\"plugin\": \"flights\", \"kind\": \"search\", \"key\": \"b\", \"title\": \"the day before\", \"at\": $(at '2026-10-01 12:00')}" | rec

# --- the day --------------------------------------------------------------------------------------
out=$(vd)
expect "the day's title ($(head -1 <<<"$out"))" has "Friday 2 October 2026" "$out"
expect "at the desk from midnight to now, the screen's time added up" has "at the desk 00:00 to 18:00, 7 h 41 min with the screen" "$out"
expect "what was counted" has "3 projects, 2 commits, 2 log entries" "$out"
expect "alpha: its folder, its worktree, the power cut and the window still in front" has "alpha (40%) · 6 h 36 min" "$out"
expect "beta: the workspace's project, cut back to when the idleness began" has "beta · 20 min" "$out"
expect "alpha's commits of the day, oldest first" grep -qzP 'Second thing\n[^\n]*Third thing' <<<"$out"
expect "the day before's commit shown" hasnt "First thing" "$out"
expect "alpha's next step" has "next: chapter five" "$out"
expect "beta's entry of the day" has "log: drawings (Vid): Drew the cover." "$out"
expect "gamma's entry of the day (no time, no commit)" has "log: later: Later work." "$out"
expect "the rest of the screen, over midnight too" has "Firefox: 45 min" "$out"
expect "Esploro's changes, in order" grep -qzP '09:15 moved 3 files into ~/Work\n[^\n]*09:20 trashed "old \(1\)\.txt" \(undone\)' <<<"$out"
expect "Esploro's change of the day before shown" hasnt "the day before" "$out"
expect "an agent's session and the settings changed before the next snapshot" grep -qzP '08:05 claude; in your settings, changed before the next snapshot:\n[^\n]*\.stumpwm\.d/user\.lisp \(\+1 -0\)' <<<"$out"
expect "the last session: changed since" grep -qzP '17:00 codex; in your settings, changed since:\n[^\n]*\.stumpwm\.d/user\.lisp \(\+1 -0\)' <<<"$out"
expect "Vikix's updates" has "Vikix updated 2 times, to 0.9.2" "$out"
expect "another snapshot" has "09:30 snapshot: before: a rule for Firefox" "$out"
expect "the rules that ran" has "rules that ran: nmtui ×2, at 09:00" "$out"
expect "documents opened, each once" test "$(grep -c 'ls(1) — list directory contents' <<<"$out")" = 1
expect "the second document" has "11:10 Rules" "$out"
expect "a few records are listed" has "flights search: DXB LHR 12 Nov" "$out"
expect "many records are counted" has "ai-usage usage: 4, the last: plan 4" "$out"

# --- the file ---------------------------------------------------------------------------------------
file="$home/journal/2026-10-02.org"
expect "the run says where it's kept" has "kept as ~/journal/2026-10-02.org" "$out"
expect "the file is there" test -f "$file"
expect "the file is yours alone ($(stat -c %a "$file" 2>/dev/null))" test "$(stat -c %a "$file")" = 600
expect "the folder is yours alone" test "$(stat -c %a "$home/journal")" = 700
expect "Org headings" grep -qx '\* Projects' "$file"
expect "a project is a second heading" grep -qxF '** alpha (40%) · 6 h 36 min' "$file"
expect "commits are points under a point" grep -qE '^  - [0-9a-f]+ Second thing$' "$file"
expect "it ends with Notes" test "$(tail -1 "$file")" = "* Notes"
printf 'A thought of my own.\n** and a heading\n' >> "$file"
vd >/dev/null
expect "written again, what's under Notes is kept" test "$(tail -3 "$file")" = "$(printf '* Notes\nA thought of my own.\n** and a heading')"
expect "written again, once" test "$(grep -c '^\* The day$' "$file")" = 1
rm "$file"
out=$(vd --no-file)
expect "--no-file prints" has "alpha (40%)" "$out"
expect "--no-file writes none" test ! -e "$file"
expect "path" test "$(vd path yesterday)" = "$home/journal/2026-10-01.org"
out=$(vd yesterday --no-file)
expect "yesterday: its commits" has "First thing" "$out"
expect "yesterday: gamma's" has "Earlier work" "$out"
expect "yesterday: the evening's screen only" has "at the desk 23:50 to 00:00, 10 min with the screen" "$out"
out=$(vd 2026-09-30 --no-file)
expect "a repo of many projects: a commit is its folder's project's ($(grep -c commit <<<"$out") lines)" grep -qzP 'series/one\n[^\n]*2 commits\n[^\n]*One only\n[^\n]*Both of them' <<<"$out"
expect "a commit across two projects counts for both" grep -qzP 'series/two\n[^\n]*1 commit\n[^\n]*Both of them' <<<"$out"
expect "a commit outside them is the repo's own project's" grep -qzP '  series\n[^\n]*1 commit\n[^\n]*The series. own' <<<"$out"
expect "what was counted there" has "3 projects, 4 commits, 0 log entries" "$out"
out=$(vd 2026-10-03 || true)
expect "a day that hasn't happened is refused" has "hasn't happened yet" "$out"
echo "folder = $home/Notes/diary   # mine" > "$home/.config/vikix/day"
vd >/dev/null
expect "folder= in ~/.config/vikix/day" test -f "$home/Notes/diary/2026-10-02.org"
rm -r "$home/.config/vikix/day" "$home/Notes"

# --- --for and --week -----------------------------------------------------------------------------
out=$(vd --for alph)
expect "--for: the project" has "alpha (40%) · 6 h 36 min" "$out"
expect "--for: no other project" hasnt "beta" "$out"
expect "--for: none of the rest" hasnt "Esploro" "$out"
expect "--for writes no file" test ! -e "$file"
out=$(vd --week)
expect "--week: its title" has "The week to Friday 2 October 2026" "$out"
expect "--week: a line a day" has "Fri  2  00:00 to 18:00, 7 h 41 min with the screen" "$out"
expect "--week: a day without a record" has "Sat 26  no record of the screen" "$out"
expect "--week: alpha over its two days" has "alpha (40%) · 6 h 36 min, 2 days, 3 commits, 1 log entry" "$out"
expect "--week: alpha's day" has "Fri  2  6 h 36 min, 2 commits" "$out"
expect "--week: an entry by its words" has "Thu  1  1 commit, log: chapter four" "$out"
out=$(vd --week --for beta)
expect "--week --for: only that project" hasnt "alpha" "$out"

# --- day log -------------------------------------------------------------------------------------------
before=$(cat "$src/alpha/log.md")
out=$(vd log </dev/null)
expect "log, no terminal: alpha is offered" has "alpha (40%): 6 h 36 min, 2 commits, no entry for 2026-10-02" "$out"
expect "log, no terminal: the draft from its commits" has "draft: Second thing. Third thing." "$out"
expect "log, no terminal: how to write it" has 'vikix project log alpha "Second thing. Third thing."' "$out"
expect "log: a project with its entry isn't offered" hasnt "beta" "$out"
expect "log, no terminal: nothing written" test "$(cat "$src/alpha/log.md")" = "$before"
# In a terminal: yes, a next step, a percentage.
pty() {   # pty ANSWERS CMD...: the command in a terminal of its own, the answers typed
  python3 - "$@" <<'EOF'
import os, pty, sys
answers, cmd = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
os.write(fd, answers.encode())
out = b""
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace").replace("\r", ""))
EOF
}
out=$(HOME=$home PATH="$t0/bin:$PATH" VIKIX_TODAY=2026-10-02 VIKIX_NOW=$(at "2026-10-02 18:00:30") \
      pty $'y\nship it\n55\n' python3 "$here/bin/vikix-day" log)
got=$(cat "$src/alpha/log.md")
expect "log, in a terminal: it says so ($(tail -3 <<<"$out" | tr '\n' ' '))" has "wrote the entry for 2026-10-02" "$out"
expect "log: the entry, by Vid, above the day before's" grep -qzP '## 2026-10-02 \(Vid\)\n\nSecond thing\. Third thing\.\n\nNext: ship it\n\n## 2026-10-01' <<<"$got"
expect "log: the percentage and its date" has "as of 2026-10-02: 55% complete." "$got"
expect "log: 40% is now 55%" has "40% is now 55%" "$out"
out=$(vd log </dev/null)
expect "log: nothing left to offer" has "has its log entry" "$out"
# The day before's entry goes below the day's.
out=$(HOME=$home PATH="$t0/bin:$PATH" VIKIX_TODAY=2026-10-02 VIKIX_NOW=$(at "2026-10-02 18:00:30") \
      pty $'e\nIn my words\n\n' python3 "$here/bin/vikix-day" log yesterday)
expect "log yesterday: your own words, below the newer entry" grep -qzP '## 2026-10-02 · later\n\nLater work\.\n\n## 2026-10-01 \(Vid\)\n\nIn my words\n' "$src/gamma/log.md"
out=$(HOME=$home PATH="$t0/bin:$PATH" VIKIX_TODAY=2026-10-03 pty $'n\n' python3 "$here/bin/vikix-day" log yesterday)
expect "log: a no writes nothing" test "$(cat "$src/alpha/log.md")" = "$got"

# --- vikix day, and the catalogue's note ------------------------------------------------------
out=$(HOME=$home PATH="$t0/bin:$PATH" VIKIX_TODAY=2026-10-02 "$here/bin/vikix" day --no-file 2>&1)
expect "vikix day reaches it" has "Friday 2 October 2026" "$out"
expect "vikix day help" has "vikix day log" "$(HOME=$home "$here/bin/vikix" day help 2>&1)"
expect "vikix docs notes what it opens" grep -q 'note_opened(doc)' "$here/bin/vikix-docs"
d="$t0/docs-home"; mkdir -p "$d"
HOME=$d python3 - "$here/bin/vikix-docs" <<'EOF'
import importlib.util, sys
from importlib.machinery import SourceFileLoader
sys.dont_write_bytecode = True
loader = SourceFileLoader("vikix_docs", sys.argv[1])
mod = importlib.util.module_from_spec(importlib.util.spec_from_loader("vikix_docs", loader))
loader.exec_module(mod)
mod.note_opened({"id": "man:ls", "title": "ls(1)\t— list"})
EOF
expect "the note: time, id, title on one line" grep -qP '^\d+\tman:ls\tls\(1\) — list$' "$d/.local/state/vikix/day/docs.log"
expect "the note is yours alone" test "$(stat -c %a "$d/.local/state/vikix/day/docs.log")" = 600

[ "$fail" = 0 ] || { echo "day: FAILED"; exit 1; }
first=$n

# --- in a real StumpWM ------------------------------------------------------------------------------
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup "day ($first checks passed; the desktop's part)"
rm -rf "$t0"   # wm_setup's trap removes its own folder; the first part's is done with
wm_start
slog="$home/.local/state/vikix/day/screen-$(date +%Y-%m).log"
# The test drives the ticker itself: the real one would write in between.
ask '(progn (cancel-timer *vikix-rules-timer*) (setf *vikix-day-started* nil *vikix-day-last* nil *vikix-day-away* nil *vikix-day-written* 0) (princ 1))' >/dev/null
rm -f "$slog"
lines() { cat "$slog" 2>/dev/null || true; }
mkdir -p "$t/work"
(cd "$t/work" && win one daywin)
ask '(progn (vikix-day-tick) (princ 1))' >/dev/null
check "the first tick says StumpWM started ($(lines | head -1))" grep -qP '^\d+\tstart$' "$slog"
check "then what is in front: workspace, no project, class, folder ($(lines | tail -1))" grep -qP "^\d+\tfocus\t1\t\tdaywin\t$t/work\$" "$slog"
check "never the title" bash -c "! grep -q one '$slog'"
check "the file is yours alone ($(stat -c %a "$slog" 2>/dev/null))" test "$(stat -c %a "$slog")" = 600
ask '(progn (vikix-day-tick) (vikix-day-tick) (princ 1))' >/dev/null
check "the same window isn't written again" test "$(grep -c focus "$slog")" = 1
ask '(progn (setf (gethash (current-group) *vikix-project-groups*) "alpha") (vikix-day-tick) (princ 1))' >/dev/null
check "a workspace opened for a project says so ($(lines | tail -1))" grep -qP "\tfocus\t1\talpha\tdaywin\t" "$slog"
ask '(progn (vikix-day-tick (get-universal-time) 400) (vikix-day-tick (get-universal-time) 430) (princ 1))' >/dev/null
check "away, with how long already, once" test "$(grep -cP '^\d+\taway\t400$' "$slog")" = 1
check "away: one line" test "$(grep -c away "$slog")" = 1
ask '(progn (vikix-day-tick (get-universal-time) 0) (princ 1))' >/dev/null
check "back: the window again" test "$(grep -c "focus${tab:-	}1	alpha" "$slog")" = 2
ask '(progn (vikix-day-tick (+ (get-universal-time) 301) 0) (princ 1))' >/dev/null
check "five minutes on, a beat ($(lines | tail -1))" grep -qP '^\d+\tbeat$' "$slog"
ask '(progn (when-window (:class "dayrule") :name "day rule" (title "ruled")) (princ 1))' >/dev/null
win two dayrule
check "a rule that ran ($(lines | tail -1))" grep -qP '^\d+\trule\tday rule$' "$slog"
check "the idle time is a whole number ($(ask '(princ (vikix-day-idle-seconds))'))" test "$(ask '(princ (if (integerp (vikix-day-idle-seconds)) 1 0))')" = 1
count=$(lines | wc -l)
ask '(progn (setf *vikix-day-on* nil) (vikix-day-tick (+ (get-universal-time) 900) 0) (princ 1))' >/dev/null
check "*vikix-day-on* nil: nothing written" test "$(lines | wc -l)" = "$count"
out=$(HOME=$home python3 "$here/bin/vikix-day" --no-file 2>&1)
check "vikix day reads what the desktop wrote ($(grep -m1 desk <<<"$out"))" grep -q "at the desk" <<<"$out"
check "the ticker is the rules' own" grep -q "vikix-day-tick" "$here/config/stumpwm/vikix/rules.lisp"
[ "$fail" = 0 ] || { wm_report day ""; echo "day: FAILED"; exit 1; }
wm_report day "all passed ($first checks in a made-up home, the rest in a real StumpWM)"
