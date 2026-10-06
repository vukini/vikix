#!/usr/bin/env bash
# tests/house.sh — the office's house rules (bin/vikix-agents touch, clash,
# crossings), without a screen: a made-up /proc with three agents, a
# repository with two worktrees, and the hook Claude Code runs before an edit.
#
#   An edit with nobody else on the file says nothing and is noted in the
#   journal; a file another agent has changed in its worktree makes the
#   hook ask, naming that agent (from an argument, and from the hook's JSON
#   on stdin; a tool without a file is let be); a file in another agent's
#   folder is a crossing: allowed, told to the agent, recorded (not one into an
#   agent in the home folder, which owns nothing); two agents
#   editing one file in one working copy is a clash through the journal;
#   vikix agents clash lists the files and shows both changes; the listing
#   marks them; the journal keeps only the agents still running; a process
#   with no agent above it is nothing to rule on; vikix agent gives Claude
#   Code the hook from config/claude/office.json.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
unset XDG_STATE_HOME
mkdir -p "$HOME" "$t/src"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# A repository and two worktrees of it: a desk each.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
printf 'one\ntwo\n' > ch1.md; echo notes > notes.md; git add ch1.md notes.md; git commit -q -m first
git worktree add -q "$t/src/book-a" -b a; git worktree add -q "$t/src/book-b" -b b
cd "$here"

# A made-up /proc: PID NAME FOLDER makes an agent process in it.
mkdir -p "$t/proc"; echo "5000.00 1.00" > "$t/proc/uptime"
proc() {
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
proc 1001 claude "$t/src/book-a"
proc 1002 codex "$t/src/book-b"
proc 1003 claude "$t/src/book-a"

agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1; }
touch_as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" touch "$@" 2>&1 < /dev/null; }
journal="$HOME/.local/state/vikix/office/journal.jsonl"

out=$(touch_as 1001 "$t/src/book-a/ch1.md")
check "an edit nobody else is on says nothing: '$out'" test -z "$out"
check "and is noted in the journal" grep -q '"kind": "edit".*"pid": 1001.*book-a/ch1.md' "$journal"

printf 'one\ntwo by b\n' > "$t/src/book-b/ch1.md"
out=$(touch_as 1001 "$t/src/book-a/ch1.md")
check "a file another agent has changed in its worktree makes the hook ask: $out" \
  grep -q '"permissionDecision": "ask"' <<<"$out"
check "naming that agent and where" grep -q 'codex 1002 (.*book-b) has changed it in .*book-b, uncommitted' <<<"$out"
check "and how to see both" grep -q 'vikix agents clash .*ch1.md' <<<"$out"
check "the clash is recorded" grep -q 'claude 1001 and codex 1002 on' <<<"$(VIKIX_RECORDS_DB=$t/records.db python3 "$here/bin/vikix-records" list office --kind clash)"
out=$(printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s/ch1.md","old_string":"x"}}' "$t/src/book-a" "$t/src/book-a" \
      | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "the same from the hook's JSON on stdin: $(head -c 60 <<<"$out")" grep -q '"permissionDecision": "ask"' <<<"$out"
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "a tool without a file is let be: '$out'" test -z "$out"

out=$(touch_as 1001 "$t/src/book-b/notes.md")
check "a file in another agent's folder is a crossing, told to the agent: $(head -c 80 <<<"$out")" \
  grep -q '"additionalContext": "Vikix office: .*book-b/notes.md is in .*book-b, the folder codex 1002 works in, not yours' <<<"$out"
check "allowed, not asked" not grep -q permissionDecision <<<"$out"
check "and recorded: $(agents crossings | head -2 | tail -1)" grep -q 'claude 1001 edited .*book-b/notes.md, in codex 1002' <<<"$(agents crossings)"
check "the journal has it as a crossing" grep -q '"kind": "crossing".*"with": "codex 1002"' "$journal"

proc 1004 claude "$HOME"
out=$(touch_as 1001 "$HOME/plan.md")
check "an agent in the home folder owns no folder: no crossing into it: '$out'" test -z "$out"
rm -rf "$t/proc/1004"
out=$(touch_as 1003 "$t/src/book-a/ch1.md")
check "two agents editing one file in one working copy is a clash through the journal: $(head -c 120 <<<"$out")" \
  grep -q '"permissionDecision": "ask".*claude 1001 (.*book-a) edited it too, [0-9]* s ago' <<<"$out"

out=$(agents clash)
check "vikix agents clash lists the file with the agents on it: $(tr '\n' ' ' <<<"$out")" \
  grep -q '^1 file with two agents on it:' <<<"$out"
check "the file, then each agent" grep -q '^  ch1.md$' <<<"$out"
check "claude's row" grep -q 'claude 1001 .*book-a: edited it' <<<"$out"
check "codex's row" grep -q 'codex 1002 .*book-b: changed in .*book-b' <<<"$out"
out=$(agents clash "$t/src/book-a/ch1.md")
check "with the file, each agent's change in full: $(grep -c '^== ' <<<"$out") agents" test "$(grep -c '^== ' <<<"$out")" -ge 2
check "codex's diff is there" grep -q '^+two by b' <<<"$out"
check "the one that hasn't changed it yet is said so" grep -q 'the edit is still to come' <<<"$out"
check "and whose say it is" grep -q 'Which stays is yours to say' <<<"$out"
out=$(agents clash "$t/src/book-a/notes.md")
check "a file no two are on: $out" grep -q '^No two agents are on .*notes.md' <<<"$out"

# The listing, with a stand-in desktop that knows no windows.
printf '#!/bin/sh\necho "=> NIL"\n' > "$t/eval"; chmod +x "$t/eval"
out=$(VIKIX_EVAL=$t/eval agents)
check "vikix agents says how many files two are on: $(head -1 <<<"$out")" grep -q '^3 agents, 1 file two are on:$' <<<"$out"
check "and marks the file under the agents: $(grep 'on ch1.md' <<<"$out" | head -1)" \
  grep -q '^           on ch1.md with .*codex 1002.* too (vikix agents clash ch1.md)$' <<<"$out"
check "--json has them" python3 -c '
import json, sys
agents = json.load(sys.stdin)
a = next(x for x in agents if x["pid"] == 1002)
assert a["clashes"] == [{"file": "ch1.md", "with": ["claude 1001", "claude 1003"]}], a["clashes"]' <<<"$(VIKIX_EVAL=$t/eval agents --json)"

rm -rf "$t/proc/1003"
touch_as 1001 "$t/src/book-a/ch1.md" >/dev/null
check "the journal keeps only the agents still running" not grep -q '"pid": 1003' "$journal"
check "and still the others" grep -q '"pid": 1001' "$journal"

out=$(python3 "$here/bin/vikix-agents" touch "$t/src/book-a/ch1.md" 2>&1 < /dev/null)
check "a process with no agent above it is nothing to rule on: '$out'" test -z "$out"
out=$(agents crossings --limit x || true)
check "crossings with a bad limit says what it takes: $out" grep -q 'vikix agents crossings \[--limit N\]' <<<"$out"

check "config/claude/office.json is the hook, on edits only" python3 -c '
import json
h = json.load(open("'"$here"'/config/claude/office.json"))["hooks"]["PreToolUse"]
assert h[0]["matcher"] == "Edit|Write|MultiEdit|NotebookEdit", h
assert h[0]["hooks"][0]["command"] == "vikix agents touch", h'
check "vikix agent gives Claude Code the hook, unless VIKIX_OFFICE=0" \
  grep -q 'VIKIX_OFFICE:-1.*!= 0.*\]' "$here/bin/vikix-agent"
check "with --settings, so nothing is written to the user's settings" \
  grep -q -- '--settings "$VIKIX_DIR/config/claude/office.json"' "$here/bin/vikix-agent"

[ $fail = 0 ] && echo "house: ok (the hook says nothing, asks, or tells of a crossing; clash lists and shows; the listing marks; the journal is pruned)"
exit $fail
