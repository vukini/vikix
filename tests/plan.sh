#!/usr/bin/env bash
# tests/plan.sh — the plan runner (vikix agents plan) and the office's event
# log, without a screen: a made-up project whose tests/run.sh and
# .claude/release are stand-ins, a stand-in terminal and agent, agents faked
# in a made-up /proc, and the runner driven a round at a time (--once).
#
#   A plan file is read and checked (a mistake named with its task); a task
#   after one at another desk needs a desk of its own. The first round makes
#   the desks and starts a worker at each, up to at-once, each worker's task
#   its first prompt and the record's task. A hand-in (status review) has
#   its tests run, and once they pass and the worker is dismissed the next
#   task of the chain starts at the same desk with the handoff before it; a
#   failed round's next worker is told why in the inbox, and the third
#   failure stops the desk under Needs you (status waiting by vikix). The
#   chain's end releases the desk with the project's .claude/release, held
#   for the user's yes when the gate is me; a task after desks waits for
#   their release and starts at a fresh desk. Pause starts nothing; stop
#   ends the runner; run again carries on. Each record write that others
#   wait on is a line of the month's event log.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_STATE_HOME XDG_CONFIG_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
export TESTER_CALLS="$t/calls" TESTER_FAIL="$t/fail" RELEASE_FAIL="$t/release-fail"
# A made-up display, so a worker's terminal opens: the terminal, the eval and
# the agent are stand-ins, and notify-send is one too (never the real desktop's).
export DISPLAY=:7 VIKIX_TERMINAL="$t/bin/term" VIKIX_EVAL="$t/bin/eval" VIKIX_AGENT_CMD="$t/bin/agent"
export VIKIX_PLAN_GRACE=30 VIKIX_PLAN_POLL=4
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/proc" "$t/bin"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
cat > "$t/bin/notify-send" <<'N'
#!/bin/sh
echo "$*" >> "${NOTIFIED:-/dev/null}"
N
cat > "$t/bin/term" <<'T'
#!/bin/sh
# A terminal: runs what follows -e, here, in the folder it was started in.
[ "$1" = "-e" ] && shift
exec "$@"
T
cat > "$t/bin/eval" <<'E'
#!/bin/sh
exit 0
E
cat > "$t/bin/agent" <<'A'
#!/bin/sh
# An agent: notes where it was started and its words (the task is the last).
printf '%s\t%s\n' "$PWD" "$*" >> "$AGENTS_LOG"
A
chmod +x "$t"/bin/*
export PATH="$t/bin:$PATH" NOTIFIED="$t/notified" AGENTS_LOG="$t/agents"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid VIKIX_TESTER=0 python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
gone() { rm -rf "$t/proc/$1"; }
round() { agents plan run "$plan" --once; }
wait_for() {   # wait_for WORDS COMMAND...: up to 15 s for the command's output to hold WORDS
  local _; for _ in $(seq 1 60); do grep -q "$1" <<<"$("${@:2}")" && return 0; sleep 0.25; done; return 1
}

# The project: a runner that records and fails when told, a release that merges
# the branch into main, removes the worktree and marks the record closed, as
# .claude/release does, and fails when told.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; mkdir -p tests .claude
cat > tests/run.sh <<'R'
#!/bin/sh
{ printf '%s %s:' "$PWD" "$*"; ls *.md | tr '\n' ' '; echo; } >> "$TESTER_CALLS"
if [ -f "$TESTER_FAIL" ]; then echo "=== spell (1s)"; echo "FAIL: the spell check found 2 words"; echo "FAILED: spell"; exit 1; fi
echo "all passed: spell"
R
cat > .claude/release <<'R'
#!/bin/sh
# A stand-in for .claude/release TOPIC "line": the branch onto main, the worktree gone, the record closed.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
echo "release $1: $2" >> "$RELEASES_LOG"
[ -f "$RELEASE_FAIL" ] && { echo "xx the tests failed"; exit 1; }
wt=$here-$1
git -C "$wt" rebase -q main
git -C "$here" merge -q --ff-only "$1"
python3 "$VIKIX_HANDOFF" closed "$(cd "$here" && cd "$(git rev-parse --git-common-dir)" && pwd)" "$wt" release || true
git -C "$here" worktree remove "$wt"
git -C "$here" branch -d "$1" >/dev/null
R
chmod +x tests/run.sh .claude/release; git add -A; git commit -q -m first
export RELEASES_LOG="$t/releases" VIKIX_HANDOFF="$here/lib/handoff.py"
cd "$here"
events() { cat "$HOME"/.local/state/vikix/office/events-*.jsonl 2>/dev/null || true; }

# --- The plan file, read and checked ---------------------------------------------------------
plan="$t/book.toml"
cat > "$plan" <<'P'
project = "book"
at-once = 2
gate = "me"

[[task]]
name = "intro"
desk = "part-one"
task = "Write the intro. Short and warm."

[[task]]
name = "middle"
desk = "part-one"
after = ["intro"]
task = "Write the middle, after the intro."
release = "Part one: the intro and the middle"

[[task]]
name = "index"
task = "Make the index."
no-tests = true

[[task]]
name = "cover"
after = ["middle", "index"]
task = "Design the cover."
agent = "codex"
push = true
P
out=$(agents plan status "$plan")
check "a plan file not run yet is read and shown: $(head -1 <<<"$out")" \
  grep -q '^Plan book (.*book.toml): book, 2 workers at once, your yes before a release; not running' <<<"$out"
check "its desks and tasks: $(tr '\n' '|' <<<"$out")" \
  bash -c 'grep -q "desk part-one: intro: ready to start" <<<"$1" && grep -q "desk index: index: ready to start" <<<"$1" && grep -q "desk cover: cover: after middle (part-one released), index (index released)" <<<"$1" && grep -q "^         middle               after intro" <<<"$1"' _ "$out"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\n[[task]]\nname = "b"\ndesk = "a"\nafter = ["a"]\ntask = "B"\n[[task]]\nname = "c"\ndesk = "a"\nafter = ["b"]\ntask = "C"\n' > "$t/ok.toml"
check "a chain whose afters are at its own desk is fine" grep -q 'desk a: a: ready to start' <<<"$(agents plan status "$t/ok.toml")"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\n[[task]]\nname = "b"\ntask = "B"\n[[task]]\nname = "c"\ndesk = "a"\nafter = ["b"]\ntask = "C"\n' > "$t/bad.toml"
out=$(agents plan status "$t/bad.toml")
check "a task after one at another desk needs a desk of its own: $out" \
  grep -q 'task 3 (c): after b, at another desk, so it needs a desk of its own, made from main once that desk is released; a has a already' <<<"$out"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nspeed = 3\n' > "$t/bad.toml"
check "an unknown key is refused with the task named" grep -q "task 1: 'speed'? a task has name, task, desk" <<<"$(agents plan status "$t/bad.toml")"
printf 'project = "book"\ngate = "boss"\n[[task]]\nname = "a"\ntask = "A"\n' > "$t/bad.toml"
check "the gate is me or none" grep -q 'gate is "me"' <<<"$(agents plan status "$t/bad.toml")"
printf 'project = "nowhere"\n[[task]]\nname = "a"\ntask = "A"\n' > "$t/bad.toml"
check "a project that isn't there is said" grep -q 'no project called nowhere' <<<"$(agents plan status "$t/bad.toml")"
printf 'project = "book"\n[[task]]\nname = "a"\n' > "$t/bad.toml"
check "a task needs its words" grep -q 'task 1 (a): task = "..." is the worker'"'"'s job' <<<"$(agents plan status "$t/bad.toml")"
check "no plan has run yet" grep -q 'no plan has run yet' <<<"$(agents plan status)"

# --- The first round: the desks made, a worker at each, up to at-once --------------------------
out=$(round)
check "the first round says what it did: $(tr '\n' '|' <<<"$out" | cut -c1-300)" \
  bash -c 'grep -q "runner started" <<<"$1" && grep -q "\$ desk book part-one" <<<"$1" && grep -q "\$ worker .*/book-part-one Write the intro. Short and warm." <<<"$1" && grep -q "\$ worker .*/book-index Make the index. --no-tests" <<<"$1"' _ "$out"
check "two worktrees, two workers started in them, the task each one's first prompt: $(cat "$t/agents")" \
  bash -c '[ -d "$1/src/book-part-one" ] && [ -d "$1/src/book-index" ] && grep -q "^$1/src/book-part-one	Write the intro. Short and warm." "$1/agents" && grep -q "^$1/src/book-index	Make the index." "$1/agents" && [ "$(grep -c "	" "$1/agents")" = 2 ]' _ "$t"
check "the cover's desk waits (its befores at other desks)" test ! -d "$t/src/book-cover"
check "the records have the tasks" bash -c 'grep -q "^Task (user, just now): Write the intro" <<<"$(python3 "$1" handoff part-one)" && grep -q "^Tests: not run by themselves" <<<"$(python3 "$1" handoff index)"' _ "$here/bin/vikix-agents"
check "the event log has the two workers: $(events | cut -c1-100)" \
  bash -c '[ "$(grep -c "\"kind\": \"worker\"" <<<"$(cat)")" = 2 ]' <<<"$(events)"
out=$(agents plan status book)
check "the status by the plan's name: $(tr '\n' '|' <<<"$out" | cut -c1-300)" \
  bash -c 'grep -q "^Plan book .*; its runner isn.t running" <<<"$1" && grep -q "desk part-one: intro: the worker starts" <<<"$1" && grep -q "desk index: index: the worker starts" <<<"$1"' _ "$out"
proc 1001 claude "$t/src/book-part-one"; proc 1002 claude "$t/src/book-index"
sleep 2.5
out=$(round)
check "a second round starts nothing more (at-once 2, both at work): $out" test "$(grep -c "	" "$t/agents")" = 2
check "the status shows them at work" grep -q 'desk part-one: intro: claude 1001 at work' <<<"$(agents plan status book)"

# --- A hand-in: the tests run, then the worker is dismissed and the next task starts -----------
echo "intro" > "$t/src/book-part-one/intro.md"; git -C "$t/src/book-part-one" add intro.md; git -C "$t/src/book-part-one" commit -q -m intro
as 1001 handoff set --status review --summary "The intro is written" >/dev/null
check "the hand-in is an event" grep -q '"kind": "handoff".*"status": "review"' <<<"$(events)"
out=$(round)
check "the round starts the tests of a hand-in: $out" grep -q 'part-one: intro handed in; its tests started' <<<"$out"
check "and the status says so" grep -q 'desk part-one: intro: handed in (review)' <<<"$(agents plan status book)"
wait_for 'tests passed' agents handoff part-one || echo "FAIL: the tests never came back: $(agents handoff part-one | tail -5)"
check "the check is an event" grep -q '"kind": "tests done".*"ok": true' <<<"$(events)"
# The worker, a real process standing in, is dismissed once its tests are in.
sleep 300 & spid=$!; gone 1001; proc "$spid" claude "$t/src/book-part-one"
out=$(round)
check "tests passed: the worker is dismissed: $out" grep -q "part-one: intro is in; its worker dismissed, the desk goes on" <<<"$out"
check "it was asked to exit (SIGTERM)" bash -c 'for i in $(seq 1 20); do kill -0 "$1" 2>/dev/null || exit 0; sleep 0.1; done; exit 1' _ "$spid"
gone "$spid"
out=$(round)
check "the next task of the chain starts at the same desk: $out" grep -q '\$ worker .*/book-part-one Write the middle, after the intro.' <<<"$out"
check "the record's history has the intro, and the task is the middle" \
  bash -c 'grep -q "^Task (user, just now): Write the middle" <<<"$1" && grep -q "review  Write the intro" <<<"$1"' _ "$(agents handoff part-one)"
check "the middle's worker started in the same worktree" grep -q "^$t/src/book-part-one	Write the middle, after the intro.$" "$t/agents"

# --- A failed round: the next worker told why; the third failure stops the desk ---------------
proc 1003 claude "$t/src/book-part-one"
echo "middle" > "$t/src/book-part-one/middle.md"; git -C "$t/src/book-part-one" add middle.md; git -C "$t/src/book-part-one" commit -q -m middle
touch "$TESTER_FAIL"
as 1003 handoff set --status review >/dev/null
round >/dev/null
wait_for 'FAILED  tests/run.sh' agents handoff part-one || echo "FAIL: the failing tests never came back"
gone 1003
out=$(round)
check "a failed round starts the next, the failure in the inbox: $out" grep -q 'worker .*/book-part-one Write the middle, after the intro.' <<<"$out"
check "the inbox says which round and what failed: $(agents handoff part-one | grep 'round 2')" \
  grep -q 'vikix (just now): plan book, round 2 of 3 for this task: round 1 handed in (review); tests failed: failed: spell' <<<"$(agents handoff part-one)"
check "the status counts the round" grep -q 'middle .*(round 2)' <<<"$(agents plan status book)"
# The second round: the worker leaves without handing in.
proc 1004 claude "$t/src/book-part-one"; sleep 0.5; gone 1004; sleep 1.5
out=$(VIKIX_PLAN_GRACE=1 round)
check "a worker that left without handing in is a failed round too: $out" grep -q 'worker .*/book-part-one Write the middle' <<<"$out"
check "told so" grep -q 'round 3 of 3 for this task: round 2 the worker left without handing in' <<<"$(agents handoff part-one)"
# The third: tests fail again, and the desk stops under Needs you.
proc 1005 claude "$t/src/book-part-one"
echo "middle 3" > "$t/src/book-part-one/middle.md"; git -C "$t/src/book-part-one" commit -q -am middle3
as 1005 handoff set --status review >/dev/null
round >/dev/null
wait_for 'FAILED  tests/run.sh' agents handoff part-one || echo "FAIL: the third round's tests never came back"
gone 1005
out=$(round)
check "the third failure stops the desk: $out" grep -q 'needs you: part-one: middle failed 3 rounds' <<<"$out"
check "the desk is set waiting by vikix (under Needs you), with why: $(agents handoff part-one | grep -i 'status')" \
  grep -q 'Status: waiting (vikix, just now)' <<<"$(agents handoff part-one)"
check "the user is told once" bash -c '[ "$(grep -c "needs you" "$1")" = 1 ]' _ "$NOTIFIED"
check "the status says Needs you: $(agents plan status book | grep -A1 'Needs you')" grep -q '^Needs you:' <<<"$(agents plan status book)"
check "no fourth worker" test "$(grep -c 'Write the middle' "$t/agents")" = 3
round >/dev/null
check "and says it once" bash -c '[ "$(grep -c "needs you" "$1")" = 1 ]' _ "$NOTIFIED"
# The user hands the task in; the tests pass; the chain goes on to its release, held for the yes.
rm -f "$TESTER_FAIL"
echo "middle, fixed" > "$t/src/book-part-one/middle.md"; git -C "$t/src/book-part-one" commit -q -am fixed
agents handoff set --desk part-one --status finished >/dev/null
round >/dev/null
wait_for 'tests passed' agents handoff part-one || echo "FAIL: the fixed tests never came back"
out=$(round)
check "the chain's end is held for the yes (gate me): $out" grep -q 'needs you: part-one: ready to release: vikix agents plan release part-one is your yes' <<<"$out"
check "the status says so" grep -q 'ready to release: your yes' <<<"$(agents plan status book)"
check "nothing released yet" test ! -f "$RELEASES_LOG"
out=$(agents plan release part-one)
check "the yes: $out" grep -q 'yes to the release of part-one (plan book)' <<<"$out"
out=$(round)
check "the release starts: $out" grep -q 'part-one: release started (Part one: the intro and the middle)' <<<"$out"
wait_for 'release part-one' cat "$RELEASES_LOG" || echo "FAIL: the release never ran"
for _ in $(seq 1 40); do [ -d "$t/src/book-part-one" ] || break; sleep 0.25; done
check "the release stand-in merged and removed the desk" bash -c '[ ! -d "$1/src/book-part-one" ] && git -C "$1/src/book" log --oneline | grep -q middle' _ "$t"
check "the desk's closing is an event" grep -q '"kind": "closed".*"by": "release"' <<<"$(events)"
out=$(round)
check "the desk is released: $out" grep -q 'part-one: released' <<<"$out"
check "the cover still waits for the index" grep -q 'desk cover: cover: after index (index released)' <<<"$(agents plan status book)"

# --- A task with no-tests: the hand-in alone; a release that fails needs you -------------------
echo "index" > "$t/src/book-index/index.md"; git -C "$t/src/book-index" add index.md; git -C "$t/src/book-index" commit -q -m index
as 1002 handoff set --status finished >/dev/null
gone 1002
agents plan release index >/dev/null
touch "$RELEASE_FAIL"
out=$(round)
check "no tests wanted: the hand-in alone, and the release starts: $out" grep -q 'index: release started (Make the index)' <<<"$out"
wait_for 'release index' cat "$RELEASES_LOG" || echo "FAIL: the index release never ran"
sleep 1
out=$(round)
check "a release that failed needs you: $out" grep -q 'needs you: index: its release failed; .*index.release.log says why, vikix agents plan release index tries again' <<<"$out"
rm -f "$RELEASE_FAIL"
agents plan release index >/dev/null
round >/dev/null
wait_for 'release index' bash -c 'grep -c "release index" "$RELEASES_LOG"' 2>/dev/null || true
for _ in $(seq 1 40); do [ -d "$t/src/book-index" ] || break; sleep 0.25; done
check "release again: the desk released" test ! -d "$t/src/book-index"
out=$(round)
check "both befores released: the cover starts at a fresh desk, with its worker's choices: $out" \
  grep -q '\$ worker .*/book-cover Design the cover. --use codex --push' <<<"$out"
check "its worktree is made from main after the releases" bash -c '[ -f "$1/src/book-cover/intro.md" ] && [ -f "$1/src/book-cover/index.md" ]' _ "$t"
proc 1006 codex "$t/src/book-cover"

# --- Pause, stop, run again; the runner as a process; the Office's view -------------------------
out=$(agents plan pause book)
check "pause: $out" grep -q 'plan book paused: the workers at work carry on, nothing new starts' <<<"$out"
check "the status says paused" grep -q '; paused: nothing new starts' <<<"$(agents plan status book)"
out=$(agents plan run "$plan")
check "run again starts the runner as a process and carries on: $out" grep -q 'plan book runs (pid [0-9]*): 4 tasks at 3 desks of book' <<<"$out"
pid=$(sed -n 's/.*pid \([0-9]*\)).*/\1/p' <<<"$out" | head -1)
check "the status says running" grep -q "; running (pid $pid)" <<<"$(agents plan status book)"
out=$(agents plan run "$plan")
check "run while running says so: $out" grep -q 'plan book is running already' <<<"$out"
out=$(agents plan stop book)
check "stop: $out" grep -q 'plan book stopped: its runner ends, the workers at work carry on' <<<"$out"
check "the runner's process ended" bash -c 'for i in $(seq 1 40); do kill -0 "$1" 2>/dev/null || exit 0; sleep 0.25; done; exit 1' _ "$pid"
check "the log has what it did" grep -q 'runner started' <<<"$(agents plan log book)"
out=$(agents office --json)
check "the Office's snapshot has the plan, its desks and what needs you: $(python3 -c 'import json,sys; p=json.load(sys.stdin)["plans"][0]; print(p["name"], p["state"], [d["topic"] for d in p["desks"]])' <<<"$out")" \
  python3 -c 'import json,sys; p=json.load(sys.stdin)["plans"][0]; assert p["name"]=="book" and p["state"]=="stopped" and [d["topic"] for d in p["desks"]]==["part-one","index","cover"] and p["desks"][0]["released"] and p["desks"][2]["tasks"][0]["state"]=="running"' <<<"$out"

[ "$fail" = 0 ] && echo "plan: ok (a plan read and checked; desks made and workers started up to at-once; a hand-in tested, the worker dismissed, the chain's next task; failed rounds told, the third stops the desk under Needs you; the release at the chain's end, held for the yes, tried again after a failure; a task after other desks at a fresh one; pause, stop, run again; the event log)"
exit $fail
