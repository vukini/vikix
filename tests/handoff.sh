#!/usr/bin/env bash
# tests/handoff.sh — a desk's record across sessions (lib/handoff.py,
# vikix agents handoff), without a screen: a made-up home, a repository
# with a worktree for a desk, and a made-up /proc for the agents.
#
#   A desk gets a record when the user sets a task; the agent's status,
#   account and next step say who wrote them; a check keeps the commit it
#   ran on and whether the tree was dirty, and is stale once the code
#   moved on (a commit, or other uncommitted changes); a session id is
#   kept by provider, Claude Code's from the hook's own input; the record
#   survives the agent's exit and a stale pid, and the worktree's removal;
#   twenty-five writers at once lose nothing; a generic provider uses the
#   same commands; a credential, an unknown field, a bad session id or a
#   record id that is a path are refused; --json has the freshness; the
#   listing names every desk; close marks the record closed and keeps it.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/proc" "$t/bin"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# A project's repository and a desk, a worktree of it.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; printf 'one\n' > ch1.md; git add log.md ch1.md; git commit -q -m first
git worktree add -q "$t/src/book-a" -b a
cd "$here"

proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
proc 1001 claude "$t/src/book-a"
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
records="$HOME/.local/state/vikix/office/desks"

out=$(agents handoff a)
check "a desk without a record says how to start one: $out" grep -q 'has no record yet: vikix agents handoff set --task' <<<"$out"
out=$(agents handoff set --desk a --task "Fix the typos in chapter one")
check "the user sets the task: $out" grep -q 'book-a: handoff updated by user$' <<<"$out"
check "the record is one file in the office's desks, named by the desk's id" test "$(ls "$records"/*.json | wc -l)" = 1
out=$(as 1001 handoff set --status working --summary "Read ch1; fixed 3 typos" --next "run the spell check")
check "the agent at the desk sets its handoff, from its seat, signed: $out" grep -q 'updated by claude 1001, status working' <<<"$out"
out=$(as 1001 handoff check tests/run.sh house --ok --note "4 s")
check "a check keeps the commit and the clean tree, read by Vikix: $out" grep -qE 'passed tests/run.sh house on [0-9a-f]{7}, clean tree \(claude 1001\)' <<<"$out"
out=$(agents handoff a)
check "the record shows the task as the user's, the handoff as the agent's: $out" \
  bash -c 'grep -q "^Task (user, just now): Fix the typos" <<<"$1" && grep -q "^Status: working (claude 1001" <<<"$1" && grep -q "^  Read ch1; fixed 3 typos" <<<"$1" && grep -q "^  run the spell check" <<<"$1"' _ "$out"
check "the check is fresh while nothing changed" grep -q 'tests/run.sh house .*clean tree)  fresh$' <<<"$out"
check "the desk's git state now, and who is there, with what holds the rules, honestly" \
  bash -c 'grep -q "^Now: a at .*, nothing uncommitted" <<<"$1" && grep -q "^At the desk now: claude 1001" <<<"$1" && grep -q "pre-edit hooks expected from vikix agent, none seen yet" <<<"$1" && grep -q "no filesystem enforcement" <<<"$1"' _ "$out"

# Stale checks: other uncommitted changes, then a commit.
echo two >> "$t/src/book-a/ch1.md"
out=$(agents handoff a)
check "a check is stale once the tree has changes it didn't see: $out" grep -q 'stale: uncommitted changes since it ran on a clean tree' <<<"$out"
out=$(as 1001 handoff check 'tests/run.sh lint' --failed)
check "a check on a dirty tree says so: $out" grep -q 'failed tests/run.sh lint on .*, tree dirty' <<<"$out"
check "and is fresh for these very changes" grep -q 'FAILED  tests/run.sh lint .*tree dirty)  fresh$' <<<"$(agents handoff a)"
echo three >> "$t/src/book-a/ch1.md"
check "other uncommitted changes make it stale" grep -q 'FAILED  tests/run.sh lint .*stale: the uncommitted changes differ' <<<"$(agents handoff a)"
git -C "$t/src/book-a" commit -qam "ch1"
out=$(agents handoff a)
check "a commit makes every older check stale, naming both commits: $out" grep -qE 'stale: the code moved on \([0-9a-f]{7} then, [0-9a-f]{7} now\)' <<<"$out"
check "--json carries the freshness and the state now" python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["version"] == 1 and r["task"]["by"] == "user" and r["handoff"]["status"]["by"] == "claude 1001", r
assert all(c["freshness"].startswith("stale") for c in r["checks"]), r["checks"]
assert r["now"]["dirty"] == 0 and r["now"]["commit"], r["now"]
assert r["desk"]["id"] and "pid" not in r["desk"], r["desk"]' <<<"$(agents handoff a --json)"

# Sessions: by hand, and Claude Code's from the hook's own input.
out=$(as 1001 handoff session claude 0f1e2d3c-aaaa-bbbb-cccc-123456789abc)
check "a session id is noted by provider: $out" grep -q 'claude session 0f1e2d3c-aaaa-bbbb-cccc-123456789abc noted' <<<"$out"
printf '{"session_id":"11111111-2222-3333-4444-555555555555","tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' \
  "$t/src/book-a" "$t/src/book-a" | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch >/dev/null 2>&1 || true
check "the hook notes Claude Code's session id on the agent's desk, once" \
  test "$(agents handoff a --json | python3 -c 'import json,sys; print(sum(1 for s in json.load(sys.stdin)["sessions"] if s["id"].startswith("1111")))')" = 1
printf '{"session_id":"11111111-2222-3333-4444-555555555555","tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' \
  "$t/src/book-a" "$t/src/book-a" | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch >/dev/null 2>&1 || true
check "the same session again is not a second line" \
  test "$(agents handoff a --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sessions"]))')" = 2
check "the hook's proposed edits now count for the protection shown" grep -q 'claude 1001: pre-edit and pre-shell hooks (vikix agents touch): 2 edits proposed' <<<"$(agents handoff a)"

# Refusals: a credential, an unknown field, a bad session id, an id that is a path.
out=$(agents handoff set --desk a --summary "the key is ANTHROPIC_API_KEY=sk-ant-abcdefghijklmnopqrst")
check "a credential is refused, and nothing kept: $out" \
  bash -c 'grep -q "looks like it holds a credential" <<<"$1" && ! grep -rq "sk-ant" "$2"' _ "$out" "$records"
out=$(echo '{"stat": "working"}' | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" handoff set --desk a --from - 2>&1 || true)
check "an unknown field in --from is refused, naming the fields: $out" grep -q 'unknown field: stat (the fields: check, next, session, status, summary, task)' <<<"$out"
out=$(agents handoff set --desk a --status 'done')
check "a status outside the four is refused: $out" grep -q 'a status is one of working, waiting, review, finished' <<<"$out"
out=$(agents handoff session --desk a codex '../../etc/passwd')
check "a session id that is a path is refused: $out" grep -q 'a session id is letters, digits, dots, dashes' <<<"$out"
out=$(agents handoff session --desk a other 'thread-42')
check "a generic provider uses the same command: $out" grep -q 'other session thread-42 noted' <<<"$out"
check "a record id with a slash is no record" python3 -c '
import sys, importlib.util
spec = importlib.util.spec_from_file_location("h", sys.argv[1]); h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
for bad in ("../x", "abc", "/etc/passwd", "0123456789ab/"):
    try: h.record_path(bad); sys.exit(1)
    except h.HandoffError: pass' "$here/lib/handoff.py"

# --from with the whole shape, as a generic agent would write it.
printf '{"status":"review","summary":"all typos fixed","next":"merge","check":{"name":"spell","ok":true,"note":"0 left"},"session":{"provider":"other","id":"sess-9"}}' > "$t/h.json"
out=$(agents handoff set --desk a --from "$t/h.json")
check "--from FILE sets status, summary, next, a check and a session at once: $out" grep -q 'updated by user, status review' <<<"$out"
check "and the page shows them" bash -c 'grep -q "^Status: review (user" <<<"$1" && grep -q "passed  spell" <<<"$1" && grep -q "other sess-9" <<<"$1"' _ "$(agents handoff a)"

# Twenty-five writers at once: every line lands, the task stays.
before=$(agents handoff a --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["log"]))')
for i in $(seq 1 25); do (agents handoff set --desk a --summary "writer $i" >/dev/null) & done; wait
after=$(agents handoff a --json | python3 -c 'import json,sys; r=json.load(sys.stdin); print(len(r["log"]), r["task"]["text"][:3])')
check "twenty-five writers at once lose nothing: $before then $after" test "$after" = "$((before + 25)) Fix"

# The agent exits (its pid is stale), the desk stays, the record stays; then the worktree goes.
rm -r "$t/proc/1001"
out=$(agents handoff a)
check "after the agent's exit the record is there, with nobody at the desk: $out" \
  bash -c 'grep -q "^Task (user" <<<"$1" && ! grep -q "At the desk now" <<<"$1"' _ "$out"
check "the listing names the desk with its status" grep -q 'book-a  review, just now: Fix the typos' <<<"$(agents handoff list)"
out=$(agents handoff set --desk a --status waiting)
check "a stale pid in the sessions stops nothing: $out" grep -q 'status waiting' <<<"$out"
proc 1002 codex "$t/src/book-a"
check "another provider at the same desk reads the same record, and is shown with instructions only" \
  bash -c 'grep -q "^At the desk now: codex 1002" <<<"$1" && grep -q "codex 1002: instructions only, unless its hook is installed" <<<"$1"' _ "$(as 1002 handoff)"
rm -r "$t/proc/1002"
git -C "$t/src/book-a" checkout -q -- . 2>/dev/null || true
agents close a >/dev/null
check "the worktree is gone" test ! -e "$t/src/book-a"
out=$(agents handoff a)
check "a closed desk's record is kept, by name, and says so: $out" \
  bash -c 'grep -q "closed just now: the record is kept" <<<"$1" && grep -q "^Task (user, .*): Fix the typos" <<<"$1"' _ "$out"
check "the listing says the folder is gone and when it closed" grep -q 'book-a (folder gone)  waiting, .*\[closed just now\]' <<<"$(agents handoff list)"
out=$(agents handoff zzz)
check "a desk that isn't: $out" grep -q 'no desk called zzz' <<<"$out"
out=$(cd "$t" && agents handoff)
check "from nowhere, with no desk named, it says so: $out" grep -q 'no desk here: say which' <<<"$out"

[ $fail = 0 ] && echo "handoff: ok (a desk's task, handoff, checks and sessions kept apart and across sessions; stale checks said; writers at once lose nothing; refusals)"
exit $fail
